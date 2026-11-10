# inadc-odc Testing Framework

This document describes the testing approach for the inadc-odc project, including test types and execution instructions.

## Test Types

### Unit Tests

Unit tests focus on testing individual components in isolation. They are fast and help catch basic issues early.

Example unit tests include:

- Validation of product definition files
- Verification of database connection functions

### Integration Tests

Integration tests verify that components work correctly together. These tests include:

- Container health check
- ODC database initialization
- Product registration
- STAC to ODC data indexing

## Running Tests

The project uses `pytest` as the test framework, with test execution simplified through Makefile commands.

### Prerequisites

Before running tests, ensure you have installed test dependencies:

```bash
make test-deps
```

### Test Commands

1. Run all tests:
   ```bash
   make test
   ```
2. Run unit tests only:
   ```bash
   make test-unit
   ```
3. Run Integration tests only:
   ```bash
   make test-deps
   ```
4. Run tests with verbose output:
   ```bash
   make test-verbose
   ```
5. View test environment logs:
   ```bash
   make test-logs
   ```
6. Stop test environment:
   ```bash
   make test-down
   ```
7. Clean test environment:
   ```bash
   make test-clean
   ```
   This command performs a comprehensive cleanup:
   - Stops and removes test containers, volumes, network and images
   - Cleans up dangling Docker images from tests
   - Deletes pytest cache files and directories
   - Removes coverage reports
   - Deletes the test virtual environment

## Writing Tests

When adding new tests:

- **Placement**: Place unit tests in tests/unit/ and integration tests in tests/integration/.
- **Naming**: Name test files with test\_ prefix, e.g., `test_product_validation.py`.
- **Test Functions**: Name test functions with test\_ prefix, e.g., `def test_product_schema_valid()`.
- **Dependencies**: Use @pytest.mark.dependency() for tests that depend on other tests.
