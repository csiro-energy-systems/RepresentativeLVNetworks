# Created by wes148 at 29/04/2021
import asyncio
import time
from pathlib import Path

from pyppeteer import launch


def render_html(html: Path, out_dir: Path, width=1920, height=1920, wait_secs=10):
    '''
    Render an HTML file as a PNG 'screenshot' using a headless Chromium browser instance.
    :param html:
    :param out_dir:
    :param width:
    :param height:
    :param wait_secs:
    :return:
    '''
    png_files = []

    async def main():
        browser = await launch({'defaultViewport': {'width': width, 'height': height}})
        page = await browser.newPage()
        await page.goto(str(html))
        time.sleep(wait_secs)
        png_file = f'{str(out_dir)}/{str(html.name)}.png'
        await page.screenshot({'path': png_file}, fullPage=False)
        await browser.close()
        png_files.append(png_file)

    asyncio.get_event_loop().run_until_complete(main())
    return png_files


def row_major(alist, sublen):
    return [alist[i:i + sublen] for i in range(0, len(alist), sublen)]


def html_table(lol):
    html_str = '<table>\n'
    for sublist in lol:
        html_str += '  <tr><td>\n'
        html_str += '    </td><td>'.join(sublist)
        html_str += '  </td></tr>\n'
    html_str += '</table>\n'
    return html_str


def render_networks_to_png(network_dict, out_dir, base_dirs):
    Path(out_dir).mkdir(parents=True, exist_ok=True)

    all_html = []
    print(f'Scanning for HTML in: {base_dirs}...')
    for bd in base_dirs:
        files = list(Path(bd).glob(f"**/*.html"))
        print(f'Found {len(files)} html files in {bd}')
        all_html.extend(files)

    print(f'Found {len(all_html)} html files')

    from shutil import copyfile
    html_list = []
    png_files = []
    for k in network_dict.keys():
        k_out_dir = Path(out_dir) / f'k={k}'
        k_out_dir.mkdir(exist_ok=True, parents=True)
        names = network_dict[k]
        for n in names:
            files: list[Path] = [f for f in all_html if n in str(f.name)]

            for f in files:
                png_files.append(render_html(f.resolve(), k_out_dir))
                copyfile(f.resolve(), (k_out_dir / f.name).resolve())
