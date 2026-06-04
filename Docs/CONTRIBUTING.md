# Contributing to DotWeaver

Thank you for your interest in contributing to DotWeaver! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected behavior**
- **Screenshots** (if applicable)
- **Environment details** (macOS version, Mac model, DotWeaver version)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title and description**
- **Use case** explaining why this would be useful
- **Possible implementation** (optional but helpful)

### Pull Requests

1. **Fork the repository** and create your branch from `develop`
2. **Make your changes** following our coding standards
3. **Write or update tests** for your changes
4. **Update documentation** if needed
5. **Ensure all tests pass** by running `swift test`
6. **Submit a pull request** to the `develop` branch

## Development Setup

### Prerequisites

- macOS 15.0 or later
- Xcode 16.0 or later
- Swift 6.0 or later

### Building from Source

```bash
git clone https://github.com/rausth/DotWeaver.git
cd DotWeaver
swift build
```

### Running Tests

```bash
swift test
```

### Running the Application

```bash
swift run DotWeaver
```

## Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4-space indentation
- Maximum line length: 120 characters
- Use descriptive variable and function names
- Add documentation comments for public APIs

### Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Example:**
```
feat(providers): add FTPS provider with TLS support

- Implement FTPSProvider with certificate validation
- Add biometric authentication requirement
- Update documentation

Closes #42
```

## Pull Request Process

1. Update the README.md or documentation with details of changes
2. Update the CHANGELOG.md with your changes
3. The PR will be merged once:
   - All tests pass
   - Code review is approved
   - Documentation is updated
   - No merge conflicts exist

## Questions?

Feel free to open an issue with the `question` label or join our [GitHub Discussions](https://github.com/rausth/DotWeaver/discussions).

---

**Thank you for contributing!** 🎉
