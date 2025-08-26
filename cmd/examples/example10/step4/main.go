package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/ardanlabs/ai-training/foundation/client"
)

const (
	url   = "http://localhost:11434/v1/chat/completions"
	model = "gpt-oss:latest"
)

var contextWindow = 1024 * 8

func init() {
	if v := os.Getenv("OLLAMA_CONTEXT_LENGTH"); v != "" {
		var err error
		contextWindow, err = strconv.Atoi(v)
		if err != nil {
			log.Fatal(err)
		}
	}
}

// =============================================================================

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	scanner := bufio.NewScanner(os.Stdin)
	getUserMessage := func() (string, bool) {
		if !scanner.Scan() {
			return "", false
		}
		return scanner.Text(), true
	}

	agent, err := NewAgent(getUserMessage)
	if err != nil {
		return fmt.Errorf("failed to create agent: %w", err)
	}

	return agent.Run(context.TODO())
}

// =============================================================================

// DECLARE A TOOL INTERFACE TO ALLOW THE AGENT TO CALL ANY TOOL FUNCTION
// WE DEFINE WITHOUT THE AGENT KNOWING THE EXACT TOOL IT IS USING.

type Tool interface {
	Call(ctx context.Context, toolCall client.ToolCall) client.D
}

type Agent struct {
	sseClient      *client.SSEClient[client.ChatSSE]
	getUserMessage func() (string, bool)

	// WE NEED TO ADD TOOL SUPPORT TO THE AGENT. WE NEED TO HAVE A SET OF
	// TOOLS THAT THE AGENT CAN USE TO PERFORM TASKS AND THE CORRESPONDING
	// DOCUMENTATION FOR THE MODEL.
	tools         map[string]Tool
	toolDocuments []client.D
}

func NewAgent(getUserMessage func() (string, bool)) (*Agent, error) {

	// CONSTRUCT THE TOOLS MAP HERE BECAUSE IT IS PASSED ON TOOL CONSTRUCTION
	// SO TOOLS CAN REGISTER THEMSELVES IN THIS MAP OF AVAILABLE TOOLS.
	tools := map[string]Tool{}

	agent := Agent{
		sseClient:      client.NewSSE[client.ChatSSE](client.StdoutLogger),
		getUserMessage: getUserMessage,

		// ADD THE TOOLING SUPPORT TO THE AGENT.
		tools: tools,
		toolDocuments: []client.D{
			RegisterGetWeather(tools),
		},
	}

	return &agent, nil
}
