# SML Project Template

A template for Standard ML projects using MLton with a modern build system.

## Features

- **MLton Integration**: Optimized for MLton compiler with proper MLB file organization
- **Multi-Profile Builds**: Separate configurations for development, production, and testing
- **TOML Configuration**: Modern, readable project configuration
- **Modular Architecture**: Clean separation between core libraries, CLI, and tools
- **AI-Friendly**: Includes coding standards and guidelines for AI-assisted development

## Quick Start

1. Clone this template
2. Update `Project.toml` with your project details:

   ```toml
   [project]
   name = "your-project-name"
   version = "0.1.0"
   ```

3. Build the project:

   ```bash
   make         # Builds production binaries
   make dev     # Builds development binaries
   make test    # Builds test binaries
   ```

   You can run binaries directly from the `build/` directory:

   ```bash
   ./build/your-project-name-dev --help
   ```

## Project Structure

```text
├── Project.toml          # Project configuration
├── Makefile             # Build system
├── src/                 # Source code
│   ├── core/           # Core libraries
│   ├── cli/            # CLI-specific code
│   ├── bins/           # Binary entry points
│   └── test/           # Tests
├── mlb/                # MLton Basis files
└── tools/              # Build tools
```

## Build Profiles

- **dev**: Development build with debugging enabled
- **prod**: Production build with optimizations
- **test**: Test build with additional testing support

## Configuration

All project configuration is centralized in `Project.toml`. The build system automatically generates Makefile variables from this configuration.

## Requirements

- MLton compiler
- Python 3 (for build tools)
- Make

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.
