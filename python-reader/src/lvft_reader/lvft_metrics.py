import collections
import concurrent
import logging
import multiprocessing
from collections import OrderedDict

import ditto
import networkx as nx
import numpy as np
import pandas as pd
from ditto import Store
from ditto.metrics.network_analysis import NetworkAnalyzer
from ditto.models import PowerTransformer, Line, Load
from ditto.models.node import Node
from ditto.models.power_source import PowerSource
from networkx import Graph
from tqdm import tqdm

from lvft_reader import ditto_utils

logger = logging.getLogger(__name__)


class LVFTMetrics():
    """
    Functions for calculating various low voltage network metrics from a collection of Ditto Stores
    """

    count = 0

    def generate_report(self, dnsp_model_dict: dict, single_process=False):
        ''' Generate a basic report on parsing results '''
        # report = generate_report(dnsp_samples)

        report: pd.DataFrame = pd.DataFrame()

        df_list = []

        if single_process:
            for dnsp, model in dnsp_model_dict.items():
                for mdl in tqdm(model, desc=f'Generating network report for {dnsp}'):
                    row = self.generate_report_row(mdl, dnsp, self.count)
                    df_list.append(row)
                    self.count += 1
        else:
            # Multiprocess this to speed it up (esp. for Tas and Ausgrid)
            ditto_utils.set_low_priority()
            with concurrent.futures.ProcessPoolExecutor(multiprocessing.cpu_count() * 2) as executor:
                futures = []

                for dnsp, model in dnsp_model_dict.items():
                    for mdl in model:
                        futures.append(executor.submit(self.generate_report_row, mdl, dnsp, self.count))
                        self.count += 1
                for f in tqdm(concurrent.futures.as_completed(futures), desc=f'Generating network reports', total=len(futures)):
                    pass
                concurrent.futures.wait(futures)
                df_list.extend([f.result() for f in futures])

        ditto_utils.set_normal_priority()

        report = pd.concat(df_list)
        report = report.sort_values(by=['dnsp', 'name'])
        # report = report.sort_index(axis='columns')
        return report

    def generate_report_row(self, mdl: Store, dnsp: str, count: int):
        '''
            Calculates metrics describing the given model.  Also appends all ditto metrics.

            Counts / category metrics:
                •✓	Amount of nodes
                •✓	Amount of edges
                •✓	Is the topology radial?
                •✓	Amount of three-phase vs single-phase nodes / lines
                •	Dominant config: three-phase with neutral / without neutral / split-phase (ditto nominal voltages_1: split <400, 400<3ph<433
                •✓	Amount of nodes of degree 1, 2, 3, 4, >4 (absolute or percentage)


            Statistical features (min, mean, median, max):
                •✓	Overhead/underground
                •✓	Cable cross section (wire.gmr)
                •	Conductor material (wire.diameter)
                •✓	Node Degree (ditto's 'avg_degree')
                •✓	Distance to LV substation from all nodes for
                o✓	    Length
                o✓	    Hops
                o✓	    Impedance
                •	Current limit
                •✓	Number of wires per line
                •	Amount of feeders
                •	Amount of service lines
                •✓	Amount of nodes/lines/loads at each nominal voltage


        :param mdl: the ditto model
        :param dnsp: string describing the DNSP (distribution network service provider)
        :param count: an integer index for this network
        :return:
        '''
        try:
            mdl.set_names()

            powersources = [l for l in mdl.models if isinstance(l, PowerSource)]
            source = ditto_utils.get_power_sources(mdl)[0]

            positions = [p.positions for p in mdl.models if hasattr(p, 'positions') and p.positions is not None and p.positions != []]  # get Positions from model attribute
            positions.extend([[p] for p in mdl.models if isinstance(p, ditto.models.position.Position)])  # get Positions that were put directly into from store.model
            lats = [k[0].lat for k in positions if k[0].lat is not None and k[0].lat != 0]
            longs = [k[0].long for k in positions if k[0].long is not None and k[0].long != 0]
            avg_lat = pd.Series(lats, dtype='float64').dropna().mean()
            avg_long = pd.Series(longs, dtype='float64').dropna().mean()

            # anc_data = adg.ancillary_lookup(avg_lat, avg_long)

            stats = collections.OrderedDict()
            stats['dnsp'] = dnsp
            stats['name'] = mdl.name
            stats['file'] = mdl.source_file if hasattr(mdl, 'source_file') else None
            stats['avg_lat'] = None if not hasattr(mdl, 'avg_lat') else mdl.avg_lat
            stats['avg_long'] = None if not hasattr(mdl, 'avg_long') else mdl.avg_long
            stats['n_lat_long'] = len(lats)
            if hasattr(mdl, 'ancillary_data'):
                stats.update(mdl.ancillary_data)

            ''' Stats for cycle removal '''
            if hasattr(mdl, 'edge_type_df'):
                stats['n_line_types'] = mdl.edge_type_df.shape[0] if mdl.edge_type_df is not None else np.nan

            if hasattr(mdl, 'cycles_removed'):
                stats['cycles_removed'] = mdl.cycles_removed

            network = mdl._network
            network.build(mdl, source=source)
            graph: Graph = network.graph

            types = ['n_' + type(m).__name__ for m in mdl.model_store]
            class_counts = collections.Counter(types)
            stats.update(class_counts)

            ''' Count duplicate model names.  Probably indicates parsing errors'''
            name_counts = collections.Counter([m.name for m in mdl.models if hasattr(m, 'name')])
            dup_names = {name: name_counts[name] for name in name_counts.keys() if name_counts[name] > 1}
            stats['n_duplicate_names'] = len(dup_names)

            ''' Count disconnected subgraphs.  Values >1 may indicate a parsing issue or incorrectly set switch state '''
            stats['n_disconnected_graphs'] = len(list((graph.subgraph(c) for c in nx.connected_components(graph))))

            ''' Number of graph cycles/loops '''
            stats['n_cycles'] = len(nx.algorithms.cycles.cycle_basis(graph))

            ''' Basic stats for the whole network '''
            net_stats, loads, lines, nodes, transformers = self.calc_network_stats(graph, mdl, source)
            stats.update(net_stats)

            ''' Counts of nominal Load voltages '''
            nominal_voltages = np.histogram([l.nominal_voltage for l in loads if hasattr(l, 'nominal_voltage') and l.nominal_voltage is not None], bins=[1, 300, 500, np.inf])
            voltage_keys = [240, 400, 11000]
            nominal_voltages = OrderedDict(dict(zip(voltage_keys, nominal_voltages[0])))
            for voltage, count in nominal_voltages.items():
                stats[f'n_loads_{voltage if voltage < 11000 else ">400"}V'] = count

            ''' Counts of nominal Line voltages '''
            nominal_voltages = np.histogram([l.nominal_voltage for l in lines if hasattr(l, 'nominal_voltage') and l.nominal_voltage is not None], bins=[1, 300, 500, np.inf])
            voltage_keys = [240, 400, 11000]
            nominal_voltages = OrderedDict(dict(zip(voltage_keys, nominal_voltages[0])))
            for voltage, count in nominal_voltages.items():
                stats[f'n_lines_{voltage if voltage < 11000 else ">400"}V'] = count

            ''' Counts of nominal Node voltages '''
            nominal_voltages = np.histogram([l.nominal_voltage for l in nodes if hasattr(l, 'nominal_voltage') and l.nominal_voltage is not None], bins=[1, 300, 500, np.inf])
            voltage_keys = [240, 400, 11000]
            nominal_voltages = OrderedDict(dict(zip(voltage_keys, nominal_voltages[0])))
            for voltage, count in nominal_voltages.items():
                stats[f'n_nodes_{voltage if voltage < 11000 else ">400"}V'] = count

            if hasattr(powersources[0], 'rated_power'):
                stats['powersource_rated_power'] = powersources[0].rated_power

            if hasattr(powersources[0], 'phases'):
                stats['powersource_n_phases'] = len(powersources[0].phases)

            ''' TODO finish this. Number of phases on transformer secondary '''
            # windings = [l.windings for l in transformers if hasattr(l, 'windings') and l.windings is not None]
            # voltage_winding_counts = {w for w in windings}
            # for windings, count in node_degrees.items():
            #     stats[f'n_{int(windings)}_windings'] = count

            ''' Cable cross section (wire.gmr) and diameters '''
            wires = [l.wires for l in mdl.models if isinstance(l, Line)]
            wires = [item for sublist in wires for item in sublist]  # flatten nested lists
            cross_sections = [w.gmr for w in wires if w.gmr is not None and not np.isnan(w.gmr)]
            if len(cross_sections) > 0:
                stats['min_wire_radius'] = np.nanmin(cross_sections)
                stats['max_wire_radius'] = np.nanmax(cross_sections)
                stats['mean_wire_radius'] = np.nanmean(cross_sections)
                stats['mean_wire_radius'] = np.nanmedian(cross_sections)

            diameter = [w.diameter for w in wires if w.diameter is not None and not np.isnan(w.diameter)]
            if len(diameter) > 0:
                stats['min_wire_diameter'] = np.nanmin(diameter)
                stats['max_wire_diameter'] = np.nanmax(diameter)
                stats['mean_wire_diameter'] = np.nanmean(diameter)
                stats['mean_wire_diameter'] = np.nanmedian(diameter)

            ''' Phase identifier counts '''
            phase_counts = dict(collections.Counter(sorted([w.phase for w in wires])))
            for ph, count in phase_counts.items():
                stats[f'n_{ph}_phase_wires'] = count

            ''' Wire X/Y Positions '''
            x_pos = [w.X for w in wires if w.X is not None]
            y_pos = [w.Y for w in wires if w.Y is not None]
            if len(x_pos) > 0:
                stats['min_wire_x_pos'] = min(x_pos)
                stats['min_wire_x_pos'] = max(x_pos)
                stats['mean_wire_x_pos'] = np.nanmean(x_pos)
            if len(y_pos) > 0:
                stats['min_wire_y_pos'] = min(y_pos)
                stats['min_wire_y_pos'] = max(y_pos)
                stats['mean_wire_y_pos'] = np.nanmean(y_pos)

            ''' Number/ratio Overhead / underground lines '''
            # line_types = dict(collections.Counter(sorted([l.line_type for l in lines if hasattr(l, 'line_type')])))
            # stats.update(line_types)
            n_overhead_lines = len(([l for l in lines if hasattr(l, 'line_type') and l.line_type == 'overhead']))
            n_underground_lines = len(([l for l in lines if hasattr(l, 'line_type') and l.line_type == 'cable']))
            stats['n_overhead_lines'] = n_overhead_lines
            stats['n_underground_lines'] = n_underground_lines
            stats['ratio_lines_overhead'] = np.nan if n_overhead_lines + n_underground_lines == 0 else n_overhead_lines / (n_overhead_lines + n_underground_lines)

            ''' Feeder Stats '''
            ''' ✓ n_feeders '''
            ''' Total line length of feeders '''
            ''' Number of graph edges in the feeder '''
            ''' Total number of nodes  in the feeder '''
            ''' Amount of nodes of degree 1, 2, 3, 4, >4 (absolute or percentage) '''
            ''' Number of Wires in the feeder '''
            ''' Distance (length, hops & impedance) to LV substation from all nodes ('*_to_sub') '''
            ''' n_distinct_line_types (a byproduct of finding feeders and removing cycles) '''
            ''' Min/Max/Avg/Median feeder length '''
            ''' Distance (length, hops & impedance) to LV substation from all Feeder nodes  '''

            feeder_sub_stats = []
            feeder_lines = []
            if hasattr(mdl, 'feeder_head_node') and hasattr(mdl, 'feeder_subgraphs'):
                for feeder in mdl.feeder_subgraphs:
                    to_feeder, _, flines, _, _ = self.calc_network_stats(feeder, mdl, mdl.feeder_head_node, 'feeder_avg_', parent_graph=graph)
                    feeder_lines.extend(flines)
                    feeder_sub_stats.append(to_feeder)

                stats['n_feeders'] = len(mdl.feeder_subgraphs)

                stats['feeder_total_line_length'] = sum([x.length for x in feeder_lines])

                ''' Number of graph edges'''
                stats['feeder_total_n_edges'] = sum([len(graph.edges) for graph in mdl.feeder_subgraphs])

                ''' Total number of nodes '''
                stats['feeder_total_n_nodes'] = sum([len(graph.nodes) for graph in mdl.feeder_subgraphs])

                ''' Take the average of all the usual stats across all feeders '''
                df = pd.DataFrame(feeder_sub_stats)
                feeder_avg_stats = df.mean(axis='rows')
                stats.update(feeder_avg_stats.to_dict())

            ditto_metrics = self.get_ditto_metrics(mdl)
            stats.update(ditto_metrics)

            # ''' Store all lats and longs in a cell.  Have to create column and set dtype to object for this to work.'''
            # if 'all_lat_longs' not in report.columns:
            #     report['all_lat_longs'] = np.nan
            #     report['all_lat_longs'] = report['all_lat_longs'].astype('object')
            # if not pd.Series(lats).isna().all() and not pd.Series(longs).isna().all():
            #     report.at[count, 'all_lat_longs'] = dict(zip(lats, longs))

            return pd.DataFrame(index=[count], data=stats, columns=stats.keys())
        except BaseException as e:
            logger.warning(f'Error calculating metrics for row {count}, dnsp: {dnsp}, model: {mdl.name}', exc_info=True)
            return pd.DataFrame(index=[count], data={'metrics_error': str(e)})

    def get_ditto_metrics(self, store) -> dict:
        '''
        Try to compute the metrics.  See https://nrel.github.io/ditto/metrics/ for metrics descriptions.
        # TODO make some effort to actually identify feeders based on continuous distinct line properties

        :param store: the ditto Store model, which should contain only a single LV network, from which to calculate the metrics.
        :return: a dict containing all calculated metrics.
        '''
        try:
            # Add the feeder information to the network analyzer so metrics can be computed
            ''' There should only be one power source per LV network, just get its name. '''
            source_bus_name = ditto_utils.get_power_sources(store)[0]

            ''' Ditto makes you set some info about the feeder(s) inside the network before it will calculate metrics. 
                We don't have a good way of identifying the actual feeder lines/nodes (yet), so just include all non-load nodes in the LV network.
                Unclear what feeder_types is used for - think it's just an arbitrary string. 
            '''
            # Ditto defines network nodes as anything with a from, to or connecting element, so we'll duplicate this logic when defining the feeder nodes.
            feeder_nodes = [[i.name for i in store.models if
                             (hasattr(i, "from_element") and i.from_element is not None and
                              hasattr(i, "to_element") and i.to_element is not None) or
                             (hasattr(i, "connecting_element") and i.connecting_element is not None)]]
            feeder_names = [source_bus_name]
            substations = {source_bus_name: source_bus_name}
            feeder_types = [source_bus_name]

            network_analyst = NetworkAnalyzer(store, True, source_bus_name)
            network_analyst.add_feeder_information(feeder_names, feeder_nodes, substations, feeder_types)
            network_analyst.split_network_into_feeders()
            network_analyst.compute_all_metrics(source_bus_name)
            # logger.info(f'Metrics: \n{network_analyst.results}')

            ''' Ditto returns a nested dict structure.  Flatten this and drop missing and non-scalar values, or anything with named keys (eg 'wire' metrics)'''
            flat = flatten_dict(network_analyst.results[source_bus_name])
            flat = {i: j for i, j in flat.items() if j is not None and
                    not i.startswith('wire') and
                    not i.startswith('power_factor_distribution') and
                    not isinstance(j, list) and
                    not isinstance(j, dict)}

            return flat

        except BaseException as e:
            logger.warning(f'Unable to compute ditto metrics for network: {store.name}', exc_info=True)
            return {'ditto_metrics_error': repr(e)}

    def calc_to_sub_stats(self, graph: nx.Graph, mdl: Store, source: str, prefix: str = '', parent_graph=None):
        '''
        Calculates various distance metrics (length, hops & impedance) to LV substation from all nodes in the graph.
        :param graph: networkx graph in which to traverse node-to-source paths.  Maye be a subset of the model's full network.
        :param mdl: ditto model
        :param source: powersource for the network
        :param prefix: a prefix to append to stat names (dict keys)
        :param parent_graph: if graph is a feeder subgraph (which may be disconnected from the sub node), you must also provide its parent graph so the path to sub can be assessed.
        :return: stats about node-to-source paths
        '''

        hops, metres, r0s, r1s, x0s, x1s = [], [], [], [], [], []
        for node in graph.nodes:
            n = mdl.model_names.get(node)
            if isinstance(n, Node):
                total_hops = nx.algorithms.shortest_path_length(graph if parent_graph is None else parent_graph, str(node), source)
                total_metres = nx.algorithms.shortest_path_length(graph if parent_graph is None else parent_graph, str(node), source, weight='length')
                if total_metres > 0:

                    ''' Step along the path from node to power source and sum total (not per metre) impedance values '''
                    path = nx.algorithms.shortest_path(graph if parent_graph is None else parent_graph, str(node), source)
                    r0, r1, x0, x1 = 0, 0, 0, 0  # total resistance and admittance for the path from this node to the power source
                    for idx in range(len(path) - 1):
                        edge = graph.get_edge_data(path[idx], path[idx + 1])
                        if edge is not None and len(edge) > 0:
                            edge_name = edge.get('equipment_name')
                            if edge_name is None:
                                print('BLEH!')
                            line = mdl.model_names.get(edge_name)
                            if isinstance(line, Line) and line.length > 0:
                                if hasattr(line, 'impedance_matrix') and line.impedance_matrix is not None and len(line.impedance_matrix) > 0:
                                    lr0, lr1, lx0, lx1 = ditto_utils.get_impedance_from_matrix(line.impedance_matrix)
                                    r0 += lr0 * line.length
                                    r1 += lr1 * line.length
                                    x0 += lx0 * line.length
                                    x1 += lx1 * line.length
                                    line.R0 = r0  # set these params back on the line to help with plotting and line uniqueness calcs later
                                    line.R1 = r1
                                    line.X0 = x0
                                    line.X0 = x1
                                else:
                                    r0 += line.R0 * line.length
                                    r1 += line.R1 * line.length
                                    x0 += line.X0 * line.length
                                    x1 += line.X1 * line.length

                    hops.append(total_hops)
                    metres.append(total_metres)
                    if r0 > 0: r0s.append(r0)
                    if r1 > 0: r1s.append(r1)
                    if x0 > 0: x0s.append(x0)
                    if x1 > 0: x1s.append(x1)

        stats = OrderedDict()
        ''' Add summary stats for all nodes-to-sub measurements '''
        if len(hops) > 0:
            stats[prefix + 'max_hops_to_sub'] = round(max(hops), 3)
            stats[prefix + 'min_hops_to_sub'] = round(min(hops), 3)
            stats[prefix + 'mean_hops_to_sub'] = round(np.nanmean(hops), 3)
            stats[prefix + 'median_hops_to_sub'] = round(np.nanmedian(hops), 3)

        if len(metres) > 0:
            stats[prefix + 'min_dist_to_sub'] = round(min(metres), 3)
            stats[prefix + 'max_dist_to_sub'] = round(max(metres), 3)
            stats[prefix + 'mean_dist_to_sub'] = round(np.nanmean(metres), 3)
            stats[prefix + 'median_dist_to_sub'] = round(np.nanmedian(metres), 3)

        if len(r0s) > 0:
            stats[prefix + 'min_R0_to_sub'] = round(min(r0s), 3)
            stats[prefix + 'max_R0_to_sub'] = round(max(r0s), 3)
            stats[prefix + 'mean_R0_to_sub'] = round(np.nanmean(r0s), 3)
            stats[prefix + 'median_R0_to_sub'] = round(np.nanmedian(r0s), 3)

        if len(r1s) > 0:
            stats[prefix + 'min_R1_to_sub'] = round(min(r1s), 3)
            stats[prefix + 'max_R1_to_sub'] = round(max(r1s), 3)
            stats[prefix + 'mean_R1_to_sub'] = round(np.nanmean(r1s), 3)
            stats[prefix + 'median_R1_to_sub'] = round(np.nanmedian(r1s), 3)

        if len(x0s) > 0:
            stats[prefix + 'min_X0_to_sub'] = round(min(x0s), 3)
            stats[prefix + 'max_X0_to_sub'] = round(max(x0s), 3)
            stats[prefix + 'mean_X0_to_sub'] = round(np.nanmean(x0s), 3)
            stats[prefix + 'median_X0_to_sub'] = round(np.nanmedian(x0s), 3)

        if len(x1s) > 0:
            stats[prefix + 'min_X1_to_sub'] = round(min(x1s), 3)
            stats[prefix + 'max_X1_to_sub'] = round(max(x1s), 3)
            stats[prefix + 'mean_X1_to_sub'] = round(np.nanmean(x1s), 3)
            stats[prefix + 'median_X1_to_sub'] = round(np.nanmedian(x1s), 3)
        return stats

    def calc_network_stats(self, graph, mdl, source, prefix='', parent_graph=None):
        '''
        Calculates network stats for nodes, edges and paths to the transformer based on only the models in `mdl` which match the names of nodes and edges in `graph`.
        This allows separate calculations to be made for the entire network, and for subgraphs (like feeders)
        :param graph: the networkx graph (possibly containing a subset of objects in the ditto `mdl`) for which to calculate the stats
        :param mdl: the ditto model. Must contain all objects referenced (by mdl...name and graph...equipment_name) by the graph.
        :param source: the name of the power source in the model
        :return: a dict of stats
        '''

        stats = OrderedDict()

        node_names = list(graph.nodes)
        edge_names = [graph.edges[e].get('equipment_name') for e in list(graph.edges)]
        graph_names = [*node_names, *edge_names]
        lines = [l for l in mdl.models if isinstance(l, Line) if l.name in graph_names]
        transformers = [l for l in mdl.models if isinstance(l, PowerTransformer) if l.name in graph_names]
        loads = [l for l in mdl.models if isinstance(l, Load) if l.name in graph_names]
        nodes = [l for l in mdl.models if isinstance(l, Node) if l.name in graph_names]

        ''' Total line length of whole network'''
        stats[prefix + 'total_line_length'] = sum([x.length for x in lines])

        ''' Number of graph edges'''
        stats[prefix + 'n_edges'] = len(graph.edges)

        ''' Total number of nodes '''
        stats[prefix + 'n_nodes'] = len(graph.nodes)

        ''' Amount of nodes of degree 1, 2, 3, 4, >4 (absolute or percentage) '''
        node_degrees = np.histogram([val for (node, val) in graph.degree()], bins=[1, 2, 3, 4, 5, 6, np.inf])
        node_degrees = OrderedDict(dict(zip(node_degrees[1], node_degrees[0])))
        for k in sorted(node_degrees.keys()):
            stats[prefix + f'n_deg_{int(k) if k < 5 else ">4"}_node'] = node_degrees[k]

        ''' Number of Wires per line '''
        wire_counts = dict(collections.Counter(sorted([len(l.wires) for l in lines if hasattr(l, 'wires')])))
        for wires, count in wire_counts.items():
            stats[prefix + f'n_{int(wires)}_wire_lines'] = count

        ''' Distance (length, hops & impedance) to LV substation from all nodes  '''
        to_sub = self.calc_to_sub_stats(graph, mdl, source, prefix, parent_graph)
        stats.update(to_sub)

        return stats, loads, lines, nodes, transformers


def flatten_dict(d, parent_key='', sep='_'):
    '''
    Recursively flattens nested dicts, combining their keys for children.
    :param d:
    :param parent_key:
    :param sep:
    :return:
    '''
    items = []
    for k, v in d.items():
        new_key = parent_key + sep + str(k) if parent_key else str(k)
        if isinstance(v, collections.abc.MutableMapping):
            if len(v) == 1:
                items.append((new_key, list(v.values())[0]))
            elif len(v) > 0:
                items.extend(flatten_dict(v, new_key, sep=sep).items())
        elif isinstance(v, list):
            [items.append((f'{new_key}_{i}', c)) for i, c in enumerate(v)]
        else:
            items.append((new_key, v))
    return dict(items)
