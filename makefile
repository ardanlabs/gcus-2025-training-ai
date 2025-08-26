# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

# ==============================================================================
# Remove Ollama Auto-Run
#
# We have discovered that Ollama is installing itself to run at login on all OS.
# MacOS
# To remove this on the Mac go to `Settings/General/Login Items & Extensions`
# and remove Ollama as a startup item. Then navigate to `~/Library/LaunchAgents`
# and remove the Ollama file you will find.
#
# Linux
# sudo systemctl stop ollama.service
# sudo systemctl disable ollama.service
#

# ==============================================================================
# Mongo support
#
# db.book.find({id: 300})
#
# db.book.aggregate([
# 	{
# 		"$vectorSearch": {
# 			"index": "vector_index",
# 			"exact": true,
# 			"path": "embedding",
# 			"queryVector": [1.2, 2.2, 3.2, 4.2],
# 			"limit": 10
# 		}
# 	},
# 	{
# 		"$project": {
# 			"text": 1,
# 			"embedding": 1,
# 			"score": {
# 				"$meta": "vectorSearchScore"
# 			}
# 		}
# 	}
# ])

# ==============================================================================
# Install dependencies

install:
	brew install mongosh
	brew install ollama
	brew install mplayer
	brew install pgcli
	brew install uv
	brew install pkgconf
	brew install ffmpeg

docker:
	docker pull mongodb/mongodb-atlas-local
	docker pull ghcr.io/open-webui/open-webui:v0.6.18
	docker pull postgres:17.5

ollama-pull:
	ollama pull bge-m3:latest
	ollama pull qwen2.5vl:latest
	ollama pull gpt-oss:latest
	ollama pull hf.co/mradermacher/NuMarkdown-8B-Thinking-GGUF:Q4_K_M

python-install:
	rm -rf .venv
	uv venv --python 3.12 && \
	uv lock && \
	uv sync && \
	uv pip install -r cmd/embedding/requirements.txt

# ==============================================================================
# Ollama Settings

OLLAMA_CONTEXT_LENGTH := 32768
OLLAMA_NUM_PARALLEL := 1
OLLAMA_MAX_LOADED_MODELS := 2

# ==============================================================================
# Examples

example01:
	go run cmd/examples/example01/main.go

example02:
	go run cmd/examples/example02/main.go

example04:
	go run cmd/examples/example04/main.go

ollama-up:
	export OLLAMA_KV_CACHE_TYPE=fp8 && \
	export OLLAMA_FLASH_ATTENTION=true && \
	export OLLAMA_NUM_PARALLEL=$(OLLAMA_NUM_PARALLEL) && \
	export OLLAMA_MAX_LOADED_MODELS=$(OLLAMA_MAX_LOADED_MODELS) && \
	export OLLAMA_CONTEXT_LENGTH=$(OLLAMA_CONTEXT_LENGTH) && \
	export OLLAMA_HOST=0.0.0.0 && \
	ollama serve

ollama-logs:
	tail -f -n 100 ~/.ollama/logs/server.log

ollama-list-models:
	ollama list

ollama-check-models:
	ollama run qwen2.5vl:latest 'Hello, model!'
	ollama run gpt-oss:latest 'Hello, model!'
	ollama run mistral-small3.2:latest 'Hello, model!'

# ==============================================================================
# Go Modules support

tidy:
	go mod tidy
	go mod vendor

deps-upgrade:
	go get -u -v ./...
	go mod tidy
	go mod vendor

# ==============================================================================
# Python Dependencies

deps-python-sync:
	uv sync

deps-python-upgrade:
	uv lock --upgrade && uv sync

deps-python-outdated:
	uv pip list --outdated

# ==============================================================================
# FFMpeg test commands

ffmpeg-extract-chunks:
	rm -rf zarf/samples/videos/chunks/*
	ffmpeg -i zarf/samples/videos/test_rag_video.mp4 \
		-c copy -map 0 -f segment -segment_time 15 -reset_timestamps 1 \
		-loglevel error \
		zarf/samples/videos/chunks/output_%05d.mp4

ffmpeg-extract-frames:
	rm -rf zarf/samples/videos/frames/*
	ffmpeg -skip_frame nokey -i zarf/samples/videos/chunks/output_00000.mp4 \
		-frame_pts true -fps_mode vfr \
		-loglevel error \
		zarf/samples/videos/frames/frame-%05d.jpg

ffmpeg-check-chunk-duration:
	ffprobe -v quiet -print_format json -show_entries format=duration zarf/samples/videos/chunks/output_00000.mp4
	ffprobe -v quiet -print_format json -show_entries format=duration zarf/samples/videos/chunks/output_00002.mp4
	ffprobe -v quiet -print_format json -show_entries format=duration zarf/samples/videos/chunks/output_00003.mp4

# ==============================================================================
# curl test commands

curl-tooling:
	curl http://localhost:11434/v1/chat/completions \
	-H "Content-Type: application/json" \
	-d '{ \
	"model": "gpt-oss:latest", \
	"messages": [ \
		{ \
			"role": "user", \
			"content": "What is the weather like in New York, NY?" \
		} \
	], \
	"stream": false, \
	"tools": [ \
		{ \
			"type": "function", \
			"function": { \
				"name": "get_current_weather", \
				"description": "Get the current weather for a location", \
				"parameters": { \
					"type": "object", \
					"properties": { \
						"location": { \
							"type": "string", \
							"description": "The location to get the weather for, e.g. San Francisco, CA" \
						} \
					}, \
					"required": ["location"] \
				} \
			} \
		} \
  	], \
	"tool_selection": "auto", \
	"options": { "num_ctx": 32000 } \
	}'

# ==============================================================================

# This will establish a SSE session and this is where we will get the sessionID
# and the results of the call.
curl-mcp-get-session:
	curl -N -H "Accept: text/event-stream" http://localhost:8080/tool_list_files

# Once we have the sessionID, we can initialize the session.
# Replace the sessionID with the one you get from the SSE session.
curl-mcp-init:
	curl -X POST http://localhost:8080/tool_list_files?sessionid=$(SESSIONID) \
	-H "Content-Type: application/json" \
	-d '{ \
		"jsonrpc": "2.0", \
		"id": 1, \
		"method": "initialize", \
		"params": { \
			"protocolVersion": "2024-11-05", \
			"capabilities": {}, \
			"clientInfo": {"name": "curl-client", "version": "1.0.0"} \
		} \
	}'

# Then we can make the actual tool call. The response will be streamed in the
# session call. Replace the sessionID with the one you get from the SSE session.
curl-mcp-tool-call:
	curl -X POST http://localhost:8080/tool_list_files?sessionid=$(SESSIONID) \
	-H "Content-Type: application/json" \
	-d '{ \
		"jsonrpc": "2.0", \
		"id": 2, \
		"method": "tools/call", \
		"params": { \
			"name": "tool_list_files", \
			"arguments": {"filter": "list any files that have the name example"} \
		} \
	}'
