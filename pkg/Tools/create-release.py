#! /usr/bin/env python3

import click
import requests
import os

@click.command()
@click.argument('version', required=True)
@click.argument('assets', default=None, nargs=-1)
@click.option('--github-token', default=None)
@click.option('--draft', is_flag=True)
def main(version: str, assets: list, github_token: str, draft: bool):
    print(f'Creating Github release for: {version}')

     # First create the release
    headers = {'Accept': 'application/vnd.github+json',
               'Authorization': 'Bearer ' + github_token,
               'X-GitHub-Api-Version': '2022-11-28'}

    content = {'tag_name': version,
               'target_commitish': 'main',
               'name': version,
               'body': '',
               "draft": draft,
               'prerelease':False,
               'generate_release_notes': True}

    response = requests.post('https://api.github.com/repos/microsoft/openvmm-deps/releases', json=content, headers=headers)
    response.raise_for_status()

    release = response.json()
    print(f'Created release: {release["url"]}')

    for asset in assets:
        with open(asset, 'rb') as asset_content:
            asset_size = os.path.getsize(asset)

            # Append asset to the release assets
            headers['Content-Type'] = 'application/octet-stream'

            response = requests.post(f'https://uploads.github.com/repos/microsoft/openvmm-deps/releases/{release["id"]}/assets?name={os.path.basename(asset)}', headers=headers, data=asset_content)
            response.raise_for_status()

            print(f'Attached asset: {asset} to release: {response.json()["url"]}')

if __name__ == '__main__':
    main()
