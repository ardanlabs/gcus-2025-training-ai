package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/ardanlabs/ai-training/foundation/client"
)

type frame struct {
	fileName       string
	description    string
	classification string
	embedding      []float64
	startTime      float64
	duration       float64
	mimeType       string
	image          []byte
}

const (
	urlChat   = "http://localhost:11434/v1/chat/completions"
	urlEmbed  = "http://localhost:11439/v1/embeddings"
	modelChat = "hf.co/mradermacher/NuMarkdown-8B-Thinking-GGUF:Q4_K_M"
	// modelChat  = "mistral-small3.2:latest"
	modelEmbed = "nomic-embed-vision-v1.5"

	dimensions          = 768
	similarityThreshold = 0.80
	sourceDir           = "zarf/samples/videos/"
	sourceFileName      = "zarf/samples/videos/training.mp4"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	ctx := context.Background()

	// -------------------------------------------------------------------------

	llmChat := client.NewLLM(urlChat, modelChat)
	llmEmbed := client.NewLLM(urlEmbed, modelEmbed)

	// -------------------------------------------------------------------------

	if err := splitVideoIntoChunks(sourceFileName); err != nil {
		return fmt.Errorf("splitting video into chunks: %w", err)
	}

	// -------------------------------------------------------------------------

	totalFramesTime := 0.0

	chunksDir := filepath.Join(sourceDir, "chunks")
	fmt.Printf("\nProcessing video chunks in directory: %s\n", chunksDir)

	err := fs.WalkDir(os.DirFS(chunksDir), ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if d.IsDir() {
			return nil
		}

		if !strings.HasSuffix(path, ".mp4") {
			return nil
		}

		duration, err := getVideoDuration(filepath.Join(sourceDir, "chunks", path))
		if err != nil {
			return fmt.Errorf("get video duration: %w", err)
		}

		// Defer the total time computation until after processing the chunk.
		defer func() {
			totalFramesTime += duration
		}()

		return processChunk(ctx, llmChat, llmEmbed, sourceDir, path, totalFramesTime, duration)
	})
	if err != nil {
		return fmt.Errorf("walk directory: %w", err)
	}

	return nil
}

// -------------------------------------------------------------------------

func splitVideoIntoChunks(source string) error {
	fmt.Println("Processing Video ...")
	defer fmt.Println("\nDONE Processing Video")

	ffmpegCommand := fmt.Sprintf("ffmpeg -i %s -c copy -map 0 -f segment -segment_time 15 -reset_timestamps 1 -loglevel error zarf/samples/videos/chunks/output_%%05d.mp4", source)
	out, err := exec.Command("/bin/sh", "-c", ffmpegCommand).CombinedOutput()
	if err != nil {
		return fmt.Errorf("error while running ffmpeg: %w: %s", err, string(out))
	}

	return nil
}

// -------------------------------------------------------------------------

func getVideoDuration(filePath string) (float64, error) {
	cmd := exec.Command("ffprobe", "-v", "quiet", "-print_format", "json",
		"-show_entries", "format=duration", filePath)

	output, err := cmd.Output()
	if err != nil {
		return 0, err
	}

	var probe struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
	}

	if err := json.Unmarshal(output, &probe); err != nil {
		return 0, err
	}

	duration, err := strconv.ParseFloat(probe.Format.Duration, 64)
	if err != nil {
		return 0, err
	}

	return duration, nil
}
