from unittest.mock import patch

from gittrends.ingestion.api import download_and_upload_to_s3, file_exists


@patch("gittrends.ingestion.api.s3_client.head_object")
def test_file_exists_when_file_is_present(mock_head_object):
    mock_head_object.return_value = {}

    result = file_exists("test-bucket", "bronze/file.json.gz")

    assert result is True
    mock_head_object.assert_called_once_with(
        Bucket="test-bucket", Key="bronze/file.json.gz"
    )


@patch("gittrends.ingestion.api.file_exists")
@patch("gittrends.ingestion.api.requests.get")
def test_download_skipped_if_file_exists(mock_get, mock_file_exists):
    mock_file_exists.return_value = True

    result = download_and_upload_to_s3("2026", "06", "19", "12", "test-bucket")

    assert (
        result
        == "s3://test-bucket/bronze/year=2026/month=06/day=19/2026-06-19-12.json.gz"
    )
    mock_get.assert_not_called()
