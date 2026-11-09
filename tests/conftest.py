import pytest
import os
from dotenv import load_dotenv


def pytest_configure(config):
    config.addinivalue_line("markers", "dependency(name): mark test with dependencies")


@pytest.fixture(scope="session", autouse=True)
def load_test_env():
    """Load environment variables once at beginning of test session."""
    env_path = os.path.join(os.path.dirname(__file__), '../.env')
    print(f"Loading environment from {env_path}")
    load_dotenv(env_path)
    return None
