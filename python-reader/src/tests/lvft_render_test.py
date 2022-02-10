# Created by wes148 at 8/02/2022

import unittest
from pathlib import Path

from config.logger_config import logging
from loguru import logger

from lvft_reader import ditto_utils, parse_utils
from lvft_reader.lvft_metrics import LVFTMetrics
from lvft_reader.render_html import render_html


logger.configure(**logging)


class LVFTRenderTest(unittest.TestCase):

    def test_render_representative_dss_networks(self):
        """ Renders the final Representative Networks from the final workbook DSS files, and recalculates metrics """
        out_dir = Path('../python-reader/output').resolve()
        out_dir.mkdir(exist_ok=True)

        data_dir = Path("../data/").resolve()
        files = list(data_dir.glob('**/Master.dss'))

        dnsp_model_dict = {}

        for db in files:
            store_list: list = parse_utils.read_dss(db)
            model_name = db.parent.name
            if store_list is not None:
                for store in store_list:
                    power_source_names = ditto_utils.get_power_sources(store)
                    store.dsnp = ''
                    store.name = model_name
                    dnsp_model_dict[model_name] = [store]
                    if len(power_source_names) > 0:
                        for sourcebus in power_source_names:
                            html_file, ditto_network = ditto_utils.plot_network(store, sourcebus, f'Network {model_name}, Source {sourcebus}, Trans={store.name}', out_dir, engine='pyvis')
                            # Uncomment this to enable PNG rendering of HTML network graphs. Disabled because it fails in headless jenkins environment.
                            # render_html(html_file, out_dir)

        # TODO Some of the metrics fail to be generated on the final representative networks - something about impedance matrix conversion.
        print('Generating network report.')
        parse_report = LVFTMetrics().generate_report(dnsp_model_dict, single_process=True)
        print(f'Parse Report:\n{parse_report.to_string()}')

        print(f'Saving report CSV to {out_dir / "parse-report.csv"}')
        parse_report.to_parquet(out_dir / 'parse-report.parquet')
        parse_report.to_csv(out_dir / 'parse-report.csv')


if __name__ == '__main__':
    LVFTRenderTest().test_render_representative_dss_networks()
