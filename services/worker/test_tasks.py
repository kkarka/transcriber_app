import pytest
from unittest.mock import MagicMock, patch
from tasks import transcribe

@patch('tasks.get_redis')
# CHANGE HERE: We are mocking the 'model' variable inside tasks.py
@patch('tasks.model') 
def test_transcribe_logic_flow(mock_model, mock_get_redis, tmp_path):
    
    # 0. REDIS MOCK
    mock_redis_instance = MagicMock()
    mock_get_redis.return_value = mock_redis_instance

    # 1. SETUP
    fake_video = tmp_path / "test_video.mp4"
    fake_video.write_text("fake video content")

    # 2. MODEL MOCK: Pretend the model variable works
    mock_model.transcribe.return_value = (
        [MagicMock(text="Hello world ")], # Fake Segments
        MagicMock(duration=10)            # Fake Info
    )

    # 3. EXECUTE
    result = transcribe(str(fake_video))

    # 4. ASSERT
    assert "Hello world" in result
    assert mock_redis_instance.set.called 
    print("\n✅ Unit Test Passed! Redis and AI Model successfully mocked.")