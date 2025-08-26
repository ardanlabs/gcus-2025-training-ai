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
