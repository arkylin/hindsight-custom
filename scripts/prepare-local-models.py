#!/usr/bin/env python3
"""Trim the Full image to the local models this deployment uses."""

from huggingface_hub import scan_cache_dir, snapshot_download

REMOVE_REPOS = {
    "BAAI/bge-small-en-v1.5",
    "google/embeddinggemma-2",
}
KEEP_REPOS = (
    "hindsight-ai/hs-embed-1",
    "hindsight-ai/hs-rerank-1",
)


def main() -> None:
    cache = scan_cache_dir()
    revisions = [
        revision.commit_hash
        for repo in cache.repos
        if repo.repo_id in REMOVE_REPOS
        for revision in repo.revisions
    ]
    if revisions:
        strategy = cache.delete_revisions(*revisions)
        print(f"Removing unused model caches: {strategy.expected_freed_size} bytes")
        strategy.execute()

    for repo_id in KEEP_REPOS:
        print(f"Preparing {repo_id}: {snapshot_download(repo_id)}")

    present = {repo.repo_id for repo in scan_cache_dir().repos}
    missing = set(KEEP_REPOS) - present
    unexpected = REMOVE_REPOS & present
    if missing or unexpected:
        raise SystemExit(f"model cache verification failed: missing={sorted(missing)} unexpected={sorted(unexpected)}")


if __name__ == "__main__":
    main()
