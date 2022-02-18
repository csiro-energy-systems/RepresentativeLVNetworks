import collections
import json
import logging
import os
import webbrowser
from collections import defaultdict
from json import JSONDecodeError
from pathlib import Path

import ditto.network.network as dn
import matplotlib as mpl
import networkx as nx
import numpy as np
import pandas as pd
import psutil
import ditto
from ditto import Store
from ditto.models import Line
from ditto.models.node import Node
from ditto.models.power_source import PowerSource
from matplotlib import pyplot as plt

logger = logging.getLogger(__name__)

pyvis_options = """
var options = {
  "configure": {
        "enabled": true,
        "filter": [
            "physics"
        ]
    },
  "nodes": {
    "borderWidth": 2,
    "borderWidthSelected": 4,
    "font": {
      "size": 7,
      "face": "tahoma"
    }
  },
  "edges": {
    "color": {
      "inherit": true
    },
    "font": {
      "size": 4,
      "face": "tahoma"
    },
    "hoverWidth": 2,
    "shadow": {
      "enabled": true
    },
    "smooth": {
      "type": "continuous",
      "forceDirection": "none"
    },
    "width": 3
  },
 "physics": {
    "forceAtlas2Based": {
      "gravitationalConstant": -52,
      "centralGravity": 0.005,
      "springLength": 20,
      "springConstant": 0.095,
      "damping": 1,
      "avoidOverlap": 0.35
    },
    "maxVelocity": 150,
    "minVelocity": 0.75,
    "solver": "forceAtlas2Based"
  }
}
"""


def valid_json(o):
    try:
        json.dumps(o)
        return True
    except:
        return False


def get_discrete_colourmap(n: int, base_cmap=plt.cm.jet):
    """
    Gets a list of n RGBA colour tuples, uniformly sampled from a matplotlib colormap
    :param n: number of colors to return.
    :param base_cmap: the base colormap to sample from.
    :return: a list of n RGBA tuples
    """

    # extract all colors from the base map
    cmaplist = [base_cmap(i) for i in range(base_cmap.N)]
    # force the first color entry to be grey
    # cmaplist[0] = (.5, .5, .5, 1.0)
    # define the bins and normalize
    bounds = np.linspace(0, n, n + 1)
    norm = mpl.colors.BoundaryNorm(bounds, base_cmap.N)
    cols = [base_cmap(norm(i)) for i in bounds]
    return cols


def valid_json(o):
    try:
        json.dumps(o)
        return True
    except:
        return False


def store_to_json(store: Store, out_dir: str, filename: str):
    ''' Writes a ditto model to a JSON format '''
    from ditto.writers.json.write import Writer
    Writer(output_path=out_dir, filename=filename).write(store)


def store_to_dss(store: Store, out_dir: str):
    ''' Writes a ditto model to a DSS format '''
    from ditto.writers.opendss.write import Writer
    Writer(output_path=out_dir, log_file=out_dir + '/conversion.log').write(store)


def load_from_json(filename: str) -> ditto.Store:
    ''' Writes a ditto model to a JSON format '''
    from ditto.readers.json.read import Reader
    store = Store()
    Reader(input_file=filename).parse(store)
    return store


def prettyify(v: object):
    ''' Converts arbitrary objects to strings, with some prettification (eg. rounding floats to 3 decimal places etc) '''
    if isinstance(v, float):
        return f'{v:.3f}'
    else:
        return str(v)


def get_pos(m):
    return m['positions'][0] if 'positions' in m.keys() and m['positions'] is not None and m['positions'] != [] else None


def plot_network(model: Store, source: str, title: str, out_dir: Path = None, feeder_subgraphs=None, feeder_head_node=None, engine: str = 'pyvis',
                 line_unique_features=['R1', 'X1', 'line_type', 'nominal_voltage', 'nameclass'], show_plot=False):
    '''
    Plots a ditto model using networkx and pyvis to an HTML visualisation with colourised edges according to line characteristics, and nodes according to ditto model type.
    Useful for checking parsing correctness. There are actually 3 different rendering engines that do slightly different things, see 'engine' param for details.
    :param model: the ditto network model
    :param source: name of the powersource for this network
    :param title: title for the plot, and filename
    :param out_dir: directory to save the rendered file in. Won't save if None.
    :param engine: 'pyvis' (uses a force graph simulation for layout, and coloursnodes/edges by ditto classes) 'networkx' (quick, basic layout viz)
    :param line_unique_features: a list of features which together determine uniqueness of a Line (graph edge). Used for colouring edges.
    :return: (filename of the saved file, and the built ditto.Network)
    '''
    # TODO set lengths as weights when plotting

    G: dn.Network = dn.Network()
    G.build(model, source=source)

    if not out_dir.exists():
        out_dir.mkdir(parents=True, exist_ok=True)

    # Set the attributes in the graph
    G.set_attributes(model)

    # Equipment types and names on the edges
    edge_equipment = nx.get_edge_attributes(G.graph, "equipment")
    edge_equipment_name = nx.get_edge_attributes(G.graph, "equipment_name")

    H = nx.Graph(G.graph)
    G.is_directed = False

    f = out_dir / make_filename_safe(f'{model.dnsp if hasattr(model, "dnsp") else ""} {title}.html')

    if engine == 'pyvis':
        from pyvis.network import Network

        ''' Set node weights based on the sum of lines connected to them - not exactly what we want because a long and a short edge connected to the same node will end up similar lengths'''
        # for e in H.nodes():
        #     edges = nx.edges(H, e)
        #     sum_metres = sum(filter(None, [H.edges[e].get('length') for e in edges]))
        #     H.nodes[e]['mass'] = sum_metres/10 + 1

        for e in H.nodes():
            H.nodes[e]['mass'] = 1

        nt = Network("95%", "95%", heading=title)
        nt.from_nx(H)

        # nt.show_buttons(filter_=['physics'])  # enable this only if the set_options call is disabled - useful for tweaking the default physics settings etc, or you'll get a blank plot
        try:
            nt.set_options(pyvis_options)
        except JSONDecodeError as e:
            print(e, e.doc)
            raise e

        ''' Get colors for unique classes of nodes based on their type '''
        # Assign a colour to each edge based on its unique feature combination
        class_map = {m.name: type(m).__name__ for m in model.models if hasattr(m, 'name')}
        node_types = [type(m).__name__ for m in model.models]
        unique_node_types = np.unique(node_types)
        cmap = dict(zip(unique_node_types, get_discrete_colourmap(len(unique_node_types), base_cmap=plt.cm.tab20)))
        cmap['PowerSource'] = (1., 0., 0., 1.)  # Always make the powersource red
        cmap['PowerTransformer'] = (0., 1., 0., 1.)  # Always make the powersource blue
        cmap['NoneType'] = (0., 0., 0., 1.)  # Always make the missing types black
        node_cols = [cmap[node_types[i]] for i in range(len(node_types))]

        ''' Do stuff to nodes '''
        for idx, e in enumerate(nt.nodes):

            ''' Remove the occasional missing or non-JSON-serialisable objects from the model so it can render'''
            del_keys = []
            for key, val in e.items():
                import json
                if val is None or not valid_json(val):
                    del_keys.append(key)
            for k in del_keys:
                del e[k]

            ''' Set labels on visualisation '''
            hovers = ''.join([f'{k} = {v}<br>' for k, v in dict(sorted(e.items())).items()])
            model_type = type(model.model_names.get(e.get("name"))).__name__
            e['label'] = f'{model_type}: {e["label"]}'
            e['title'] = f'<b>Type={model_type}<br> Name={e.get("name")}</b><br>' + hovers
            e['color'] = mpl.colors.to_hex(cmap[model_type])

        ''' Determine unique classes of edges based on a subset of their attributes '''
        type_to_edge, _ = get_line_types(G.graph, line_unique_features)
        line_types = list(type_to_edge.keys())

        # Assign a colour to each edge based on its unique feature combination
        sets = np.unique(line_types)
        try:
            feat_col_map = None
            cmap = dict(zip(sets, get_discrete_colourmap(len(sets) + 1)))
            feat_col_map = {line_types[i]: cmap[line_types[i]] for i in range(len(line_types))}
        except ZeroDivisionError:
            logger.warning(f'Error getting colourmap for Lines with n={len(sets)}', exc_info=True)

        ''' Do stuff to edges '''
        for idx, e in enumerate(nt.get_edges()):

            ''' Set edge weights from their length.  This is better than setting the Node masses, but it's trickier to get the physics settings right to show the result '''
            if e.get('length') is not None and e.get('length') > 1:
                e['weight'] = e.get('length')
                # e['physics'] = False
            else:
                e['weight'] = 1
                # e['physics'] = True

            ''' Remove the occasional non-JSON-serialisable objects from the model so it can render'''
            del_keys = []
            for key, val in e.items():
                # print(f'{key}:  {val} - {type(val)}')
                if val is None or not valid_json(val):
                    del_keys.append(key)
            for k in del_keys:
                del e[k]

            ''' Set labels on visualisation '''
            hovers = ''.join([f'{k} = {v}<br>' for k, v in dict(sorted(e.items())).items()])
            e['title'] = f'<b>Name={e.get("name")}</b><br>' + hovers
            # n['title'] = 'Test Hover Label<br>other line'
            edge_type = type(model.model_names.get(e.get("name"))).__name__
            if feat_col_map is not None:
                line_type = edge_to_feat_str(e, line_unique_features)

                col = feat_col_map.get(line_type)
                if col is not None:
                    e['color'] = mpl.colors.to_hex(col)
            line_features = [f'{k} = {prettyify(v)}\n' for k, v in dict(sorted(e.items())).items() if k in line_unique_features]  # string with all unique line features
            e['label'] = f"{'' if e.get('equipment_name') is None else e.get('equipment_name')}\n" + ''.join(line_features)
            e['label'] = f'{edge_type}: {e["label"]}'

        if feeder_subgraphs is not None:
            ''' Draw feeder Lines thicker '''
            for feeder in feeder_subgraphs:
                for idx, e in enumerate(nt.get_edges()):
                    feeder_edges = feeder.edges
                    if feeder_edges is not None:
                        if (e['from'], e['to']) in feeder_edges or (e['to'], e['from']) in feeder_edges:
                            # n['color'] = mpl.colors.to_hex((0., 0., 1., 1.))
                            e['width'] = 8

        if feeder_head_node is not None:
            ''' Make the feeder_head node yellow'''
            for e in nt.nodes:
                if e['name'] == feeder_head_node:
                    e['color'] = mpl.colors.to_hex((1., 1., 0., 1.))
                    e['size'] = 15
                    break

        if out_dir is not None:
            {n['x']: n['y'] for n in nt.nodes if 'x' in n.keys()}
            nt.write_html((str(f.resolve())))
            # nx.readwrite.gml.write_gml(H, str(f.resolve())+'.gml')


    elif engine == 'networkx':
        ''' Visualise Graph '''
        pos = nx.spring_layout(H, iterations=40)

        plt.rcParams["text.usetex"] = False
        plt.figure(figsize=(20, 20))
        nx.draw_networkx_edges(H, pos, alpha=0.3, edge_color="m")
        nx.draw_networkx_nodes(H, pos, alpha=0.4, node_color="r")
        nx.draw_networkx_edges(H, pos, alpha=0.4, node_size=1, width=1, edge_color="k")
        nx.draw_networkx_labels(H, pos, font_size=9)
        edge_labels = {(u, v): '' if d.get('equipment_name') is None else d.get('equipment_name') for u, v, d in H.edges(data=True)}
        nx.draw_networkx_edge_labels(H, pos, edge_labels=edge_labels, font_size=9)
        plt.title(f"{title} - {source}")

        if out_dir is not None:
            plt.savefig(f)
            logger.info(f'Saved network plot to {f}')

        if show_plot:
            url = "file://" + os.path.abspath(str(f.resolve()))
            webbrowser.open(url)

    return f, G


def get_node_edge_properties(edges, graph, line_props):
    '''
    Builds a dataframe with various characteristics of a set of edges in a ditto network
    :param edges:
    :param net:
    :param line_props:
    :return:
    '''
    nodes = set()
    for e in edges:
        nodes.add(e[0])
        nodes.add(e[1])

    data = collections.OrderedDict()
    data.update((f, graph.edges[edges[0]].get(f)) for f in line_props)  # edges should all have the same properties, so just get their unique_feautres from the first one
    data['n_edges'] = len(edges)
    data['min_degree'] = np.min(list(dict(nx.degree(graph, nodes)).values()))
    data['avg_degree'] = np.mean(list(dict(nx.degree(graph, nodes)).values()))
    data['max_degree'] = np.max(list(dict(nx.degree(graph, nodes)).values()))
    data['sum_metres'] = sum(filter(None, [graph.edges[e].get('length') for e in edges]))
    data['n_fuses'] = sum(filter(None, [graph.edges[e].get('is_fuse') for e in edges]))
    data['n_switches'] = sum(filter(None, [graph.edges[e].get('is_switch') for e in edges]))
    data['n_recloser'] = sum(filter(None, [graph.edges[e].get('is_recloser') for e in edges]))
    return data


def line_to_feat_str(line: Line, line_unique_features: list):
    '''
    Encodes a Line to a fixed string representation containing values for all provided features. Basically, this gives us a unique key for a Line for comparing its type to other Lines.
    :param line: the ditto Line model to encode
    :param line_unique_features: list of feature (Line properties) to include
    :return:
    '''
    return str([round(line.__dict__['_trait_values'].get(f), 5) if isinstance(line.__dict__['_trait_values'].get(f), float) else line.__dict__['_trait_values'].get(f) for f in line_unique_features])


def edge_to_feat_str(edge_dict: dict, line_unique_features: list):
    '''
    Encodes a networkx edge-dict to a fixed string representation containing values for all provided features. Basically, this gives us a unique key for a Line for comparing its type to other Lines.
    :param line: the ditto Line model to encode
    :param line_unique_features: list of feature (Line properties) to include
    :return:
    '''
    return str([round(edge_dict.get(f), 5) if isinstance(edge_dict.get(f), float) else edge_dict.get(f) for f in line_unique_features])


def weighted_diameter(graph, weight_prop: str):
    '''
    Weighted graph diameter.
    See https://groups.google.com/g/networkx-discuss/c/ibP89C97BLI?pli=1
    :param graph:
    :param weight_prop:
    :return: weighted diameter
    '''
    sp = dict(nx.shortest_path_length(graph, weight=weight_prop))
    e = nx.eccentricity(graph, sp=sp)
    diameter = nx.diameter(graph, e=e)
    return diameter

def get_line_types(graph, line_unique_features):
    ''' Find the set of distinct Line types (based on a given set of attributes like impedance, lineclass etc) '''
    line_types = []
    type_to_edge = defaultdict(list)

    ''' Make sure the R/X values have been set from the matrix'''
    for e in graph.edges:
        if graph.edges[e].get('impedance_matrix') is not None and len(graph.edges[e]['impedance_matrix']) > 0:
            try:
                impedances = get_impedance_from_matrix(graph.edges[e]['impedance_matrix'])
                graph.edges[e].update(dict(zip(['R0', 'X0', 'R1', 'X1'], impedances)))
            except:
                pass

    for edge in graph.edges:
        feats = edge_to_feat_str(graph.edges[edge], line_unique_features)
        type_to_edge[feats].append(tuple(sorted(edge)))  # Have to sort the edge-to/from order because apparently this isn't fixed in networkx.
        line_types.append(str(feats))

    ''' Build a table of line types and their properties, mostly for debugging purposes '''
    ltypes = pd.DataFrame()
    for lt in type_to_edge.keys():
        edges = type_to_edge[lt]
        subgraph_props = get_node_edge_properties(edges, graph, line_unique_features)
        ltypes = ltypes.append(pd.DataFrame(index=[lt], data=subgraph_props))
        ltypes = ltypes.sort_values('R1', ascending=True)
    return type_to_edge, ltypes


def get_trivial_lines(graph, line_unique_features, short_line_threshold=1.0, trivial_line_R1_threshold=0.01, trivial_line_substrs=['removable', 'fuse', 'switch', 'connector']):
    '''
    Finds all 'trivial' Line types in the model, eg short lines, lines with very low or missing R1, 'openable' lines (switches, breakers, fuses etc).

    :param model:
    :param graph:
    :param line_unique_features: a list of line name or lineclass substrings that flag a line as trivial (which means it's considered part of every type-subgraph)
    :param short_line_threshold:
    :param trivial_line_R1_threshold:
    :param trivial_line_substrs:
    :return: trivial_edges - a list of networkx edge tuples determined to be trivial. trivial_types - line-types determined to be trivial. type_to_edge - a dict mapping line tuypes to list of edge tuples, ltypes - a pandas dataframe report on the types found
    '''

    type_to_edge, ltypes = get_line_types(graph, line_unique_features)

    ''' Get edge-tuple to edge-data-dict mapping (for cleaner code) '''
    ed = {e: graph.edges[e] for e in graph.edges}  # ed = edge-data
    ''' Find edges with missing or low R1 '''
    trivial_edges = [tuple(sorted(e)) for e in graph.edges if 'R1' not in ed[e].keys() or np.isnan(ed[e]['R1']) or (ed[e]['R1'] < trivial_line_R1_threshold)]
    ''' Find edges that are switches, fuses or breakers '''
    trivial_edges.extend([tuple(sorted(e)) for e in graph.edges if ed[e].get('is_switch') or ed[e].get('is_fuse') or ed[e].get('is_breaker')])
    ''' Find short edges '''
    trivial_edges.extend([tuple(sorted(e)) for e in graph.edges if graph.edges[e].get('length') is None or graph.edges[e].get('length') <= short_line_threshold])  # short lines
    ''' Find substrings in edge names '''
    trivial_edges.extend([tuple(sorted(e)) for e in graph.edges if any(['name' in ed[e].keys() and s.lower() in ed[e].get('name') for s in trivial_line_substrs])])

    ''' Find edge types with missing ot low R1'''
    trivial_types = ltypes[(ltypes['R1'] < trivial_line_R1_threshold) | (ltypes['R1'].isna())].index.values if 'R1' in ltypes.columns else []
    ''' Make sure all edges of trivial edge types are added'''
    if trivial_types is not None:
        trivial_edges.extend([tuple(sorted(e)) for e in graph.edges if edge_to_feat_str(graph.edges[e], line_unique_features) in trivial_types])  # add names of lines with trivial types

    return trivial_edges, trivial_types, type_to_edge, ltypes


def find_feeder_networks(model: Store, source: str, line_unique_features: list, feeder_length_percentile_threshold=10):
    '''

    Feeder Identification Heuristic.

    This heuristic uses the following logic to identify feeders:
        1.	Identify the feeder head node as the first degree>2 node (ignoring edges attached to Loads) downstream from the powersource.
            a.	If that fails it's usually because the feeder has no branches, so just assume it's the first node down from the sub.
        2.	Identify all the trivial lines and line-types. These are any lines with:
            a.	low or missing R1 values
            b.	a type that is flagged as a switch, fuse or breaker (or with a name indicating such)
            c.	very short lengths
        3.	Identify all distinct line types in the network based on uniqueness of a set of features, including: [R1, X1, line_type, nominal_voltage, nameclass]
        4.	For each distinct line type from step 3, get a subgraph containing only that line-type and trivial lines (because switches/fuses can form part of a feeder).
        5.	Connected-feeders are then identified as any line-type subgraphs from step 5 which are connected to the feeder head node and have a diameter (in metres) greater than 10% of the whole network diameter.
        6.	We also define remote-feeders, which are subgraphs that are not directly connected to the feeder head node, but have a diameter greater than their distance to it.

    Note 1: this heuristic was designed to work with Low Voltage Feeder Taxonomy network data, which is lacking a lot of Line/Node information that might have made feeder identification easier.
    Note 2: need to be careful to sort the ege tuples - (to_node, from_node) - whenever doing edge comparisons, because the order returned from various networkx functions is not fixed!!

    :param model: 
    :param source: 
    :param line_unique_features:
    :return:

    '''
    selected_feeders = []
    feeder_head_node = None
    feeder_branches = []
    try:
        logger.debug(f'Finding feeders in network "{model.name}"')

        ''' Build ditto network and networkx graphs '''
        net: dn.Network = dn.Network()
        net.build(model, source=source)
        net.set_attributes(model)  # Set the attributes in the graph
        graph = nx.Graph(net.graph)

        ''' Remove all nodes are are not ditto Nodes, Transformers or PowerSources '''
        ditto_types = {node.name: type(model.model_names.get(node.name)).__name__ for node in model.models if hasattr(node, 'name')}
        drop_nodes = [name for name, t in ditto_types.items() if t not in ['Node', 'PowerTransformer', 'PowerSource']]
        graph.remove_nodes_from(drop_nodes)

        ''' Pick the special feeder head_node (coloured yellow) as the first degree>2 Node (ignoring edges attached to Loads) downstream from the powersource. '''
        for n in list(nx.dfs_tree(graph, source=source)):
            if nx.degree(graph)[n] > 2:
                feeder_head_node = n
                break

        ''' If that fails it's usually because the feeder has no branches, so just assume it's the first node down from the sub '''
        if feeder_head_node is None:
            for n in list(nx.dfs_tree(graph, source=source)):
                if isinstance(model.model_names[n], Node):
                    feeder_head_node = n
                    break

        ''' Feeders Lines are then are all of the same type and part of a connected-subgraph originating at the head_node, excluding trivial lines/types.
        '''

        trivial_edges, trivial_types, type_to_edge, ltypes = get_trivial_lines(graph, line_unique_features)
        unique_line_types = list(type_to_edge.keys())
        logger.debug('Line type properties:\n' + ltypes.to_string())

        ''' Build a map of linetype to subgraphs of connected single-type line groups that are connected to the feeder_head. 
            We allow trivial types to form their own feeder because sometimes there are false positives (eg. lines that are just missing R1/X1 values). 
            The length filtering below should catch any truly trivial feeders. 
        '''
        source_connected_sgs = []
        remote_connected_sgs = []
        for t in [t for t in unique_line_types]:

            keep_edges = type_to_edge.get(t)
            keep_edges.extend(trivial_edges)
            type_sg = graph.edge_subgraph(tuple(keep_edges)).copy()  # subgraph with all edges of this tupe

            connected_sgs = [type_sg.subgraph(c) for c in list(nx.connected_components(type_sg))]  # subgraphs of type_subgraph for each separate group of connected components
            for s in connected_sgs:
                if feeder_head_node in s.nodes and any([nx.has_path(s, n, feeder_head_node) and n != feeder_head_node for n in s.nodes]):
                    ''' Build list of 1-type subgraphs which are connected to the feeder_head '''
                    source_connected_sgs.append(s)
                else:
                    ''' Also keep a list of the groups not connected to the feeder_head, for identifying long "remote-feeders" '''
                    remote_connected_sgs.append(s)

        ''' Identify individual feeders branches by removing the special node from the subgraph above, grabbing each remaining connected segment, then adding the special node back in '''
        feeder_branches = []
        for feeder in source_connected_sgs:
            branch_heads = list(nx.neighbors(feeder, feeder_head_node))

            for head_node in branch_heads:
                if not isinstance(model.model_names.get(head_node), PowerSource):  # Special-case: don't use the power source as a feeder-branch head
                    branch = feeder.copy()
                    del_edge = branch.edges[nx.shortest_path(branch, feeder_head_node, head_node)]
                    del_node = branch.nodes[feeder_head_node]
                    branch.remove_node(feeder_head_node)
                    branch_list = [branch.subgraph(c) for c in list(nx.connected_components(branch))]  # subgraphs of type_subgraph for each separate group of connected components
                    branch = [b for b in branch_list if head_node in b.nodes][0].copy()  # the (hopefully 1) remaining branch containing the branch-head-node

                    ''' Put the deleted node and edge back '''
                    branch.add_node(feeder_head_node, object=del_node)
                    for k, v in del_node.items():
                        branch.nodes[feeder_head_node][
                            k] = v  # We set the properties the same way ditto does, not using the standard way which creates an 'object={}' parent-dict for all the ditto key:values, ie don't use: `.add_node(n, object=dict)`

                    branch.add_edge(del_edge['from_element'], del_edge['to_element'])
                    for k, v in del_edge.items():
                        branch.edges[del_edge['from_element'], del_edge['to_element']][k] = v

                    feeder_branches.append(branch)

        ''' Find the graph diameter '''
        diameter = weighted_diameter(graph, 'length')

        ''' Choose any subgraphs that are longer than the n% of the total network length '''
        connected_sg_lengths = {s: weighted_diameter(s, 'length') for s in feeder_branches}
        connected_sg_lengths = {s: connected_sg_lengths[s] for s in connected_sg_lengths.keys() if connected_sg_lengths[s] > 1}
        # length_cutoff = np.percentile(list(connected_sg_lengths.values()), feeder_length_percentile_threshold) if len(connected_sg_lengths) > 0 else 0
        length_cutoff = diameter * feeder_length_percentile_threshold / 100.0
        selected_feeders = [sg for sg in connected_sg_lengths.keys() if connected_sg_lengths[sg] > length_cutoff]

        ''' Also include any 'remote feeders' - ie those which aren't directly connected to the feeder_head node, but
            are still have a large diameter, but only if they're 'close' to the feeder head (less than half the cutoff distance). '''
        remote_sg_lengths = {}
        for feeder in remote_connected_sgs:
            remote_sg_lengths[feeder] = weighted_diameter(feeder, 'length')
        # {k: v for k, v in sorted(remote_sg_lengths.items(), key=lambda item: item[1])}

        for sg in remote_connected_sgs:
            feeder_diameter = weighted_diameter(sg, 'length')
            if feeder_diameter > length_cutoff:
                dist_to_head = min(
                    [nx.algorithms.shortest_path_length(graph, n, feeder_head_node, weight='length') for n in sg.nodes])  # get shortest distance from any subgraph node to the feeder_head
                if dist_to_head < feeder_diameter:  # we're arbitrarily choosing the distance-to-head cutoff here.  Feel free to tweak further :)
                    selected_feeders.append(sg)

        ''' Print results/warnings '''
        if feeder_head_node is None:
            logger.warning(f'Failed to find feeder head node in model "{model.name}" with {len(graph.nodes)} nodes')
        elif selected_feeders is None or len(selected_feeders) == 0:
            logger.warning(f'For network "{model.name}", selected feeder head node as "{feeder_head_node}", but failed to find feeders in model "{model.name}" with {len(graph.nodes)} nodes')
        else:
            logger.info(
                f'For network "{model.name}", selected feeder head node as "{feeder_head_node}", and {len(selected_feeders)} branches from {len(selected_feeders)} of {len(connected_sg_lengths)} feeder candidates with length > {length_cutoff:.1f}m ({feeder_length_percentile_threshold}% of diameter: ({diameter})).')
            for idx, sg in enumerate(selected_feeders):
                length = sum(list(filter(None, [sg.edges[e].get('length') for e in sg.edges])))
                logger.debug(f'Feeder #{idx} has {len(sg.edges)} edges and length: {length}m')
                # for e in sg.edges:
                #     logger.debug(f'\tType: {edge_to_feat_str(graph.edges[e], line_unique_features)}, Edge: {e}')
    except:
        logger.error(f'Failed to find feeders for network "{model.name}"', exc_info=True)

    return selected_feeders, feeder_head_node


def is_there_a_path(_from, _to):
    """

    """
    visited = set()  # remember what you visited
    while _from:
        from_node = _from.pop(0)  # get a new unvisited node
        if from_node in _to:
            # went the path
            return True
        # you need to implement get_nodes_referenced_by(node)
        for neighbor_node in nx.get_nodes_referenced_by(from_node):
            # iterate over all the nodes the from_node points to
            if neighbor_node not in visited:
                # expand only unvisited nodes to avoid circles
                visited.add(neighbor_node)
                _from.append(neighbor_node)
    return False


def get_power_sources(store):
    '''
    Gets a list of power source names from a ditto Store object
    :param store: the store to process
    :return: list of names
    '''
    power_source_names = []
    for obj in store.models:
        if isinstance(obj, PowerSource) and obj.is_sourcebus == 1:
            power_source_names.append(obj.name)

    power_source_names = np.unique(power_source_names)
    return power_source_names


def make_filename_safe(value, allow_unicode=False):
    """
    Taken from https://github.com/django/django/blob/master/django/utils/text.py
    Convert to ASCII if 'allow_unicode' is False. Convert spaces or repeated
    dashes to single dashes. Only allows characters: '-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    """
    import unicodedata
    value = str(value)
    if allow_unicode:
        value = unicodedata.normalize('NFKC', value)
    else:
        value = unicodedata.normalize('NFKD', value).encode('ascii', 'ignore').decode('ascii')
    import string
    valid_chars = "-_.() %s%s" % (string.ascii_letters, string.digits)  # Allows: '-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return ''.join(c for c in value if c in valid_chars)


def open_switches_in_cycles(model, source, line_unique_features):
    '''
    For any cycles in the network graph, see if there are any open-able edges (eg switches, fuses, etc), and iteratively open/remove them to see if the cycle can be removed.
    We try to do this in a deterministic manner, so that repeated runs result in the same loop-free network.
    Note that this MODIFIES THE DITTO MODEL - removing 'trivial' Lines if cycles are found containing them! Pass model.copy() if this is an issue.
    Note that this process may disconnect parts of the network, in which case... AAAARGH! WHAT DO WE DO?!

    :param model:
    :param source:
    :param line_unique_features:
    :return:
    '''

    ''' Build ditto network and networkx graphs '''
    net: dn.Network = dn.Network()
    net.build(model, source=source)
    net.set_attributes(model)  # Set the attributes in the graph
    graph = nx.Graph(net.graph)

    ''' Remove all nodes are are not ditto Nodes, Transformers or PowerSources '''
    ditto_types = {node.name: type(model.model_names.get(node.name)).__name__ for node in model.models if hasattr(node, 'name')}
    drop_nodes = [name for name, t in ditto_types.items() if t not in ['Node', 'PowerTransformer', 'PowerSource']]
    graph.remove_nodes_from(drop_nodes)

    trivial_edges, trivial_types, type_to_edge, type_df = get_trivial_lines(graph, line_unique_features)

    ''' Number of graph cycles/loops '''
    cycle_list = nx.algorithms.cycle_basis(graph)
    n_cycles_orig = len(cycle_list)
    new_cycle_list = []
    pass_count = 1
    while len(cycle_list) > 0:

        removable_edges = defaultdict(list)
        if len(cycle_list) > 0:
            for cycle in cycle_list:
                cycle_edges = []
                cycle_types = []

                for idx, from_node in enumerate(cycle):
                    to_node = cycle[(idx + 1) % len(cycle)]
                    edge_key = tuple(sorted((from_node, to_node)))
                    edge_dict = graph.edges[edge_key]
                    edge_type = edge_to_feat_str(edge_dict, line_unique_features)

                    # Add the edges with trivial types first, as these (might be) more likely to be switches.  Maybe?
                    if edge_type in trivial_types:
                        removable_edges[tuple(cycle)].append(edge_key)

                    # Then add the individual trival edges. These are less likely to be switches, though it's still possible.  Maybe.
                    if (from_node, to_node) in trivial_edges:
                        removable_edges[tuple(cycle)].append(edge_key)

        if len(removable_edges) == 0:
            logger.warning(f'No more removable edges found, but still {len(cycle_list)} cycles remaining!  Giving up.')
            logger.debug(f'Remaining cycles: {cycle_list}')
            break

        for cycle in removable_edges.keys():
            edges = removable_edges[cycle]
            e = edges[0]  # Just aribtrarily pick the first removable edge to delete.  In lieu of better information about the lines, I'm not sure there's a better approach.

            ''' Remove the line from the ditto model '''
            if e in graph.edges:  # need to check because previous cycle traversals may have already removed this edge from another direction
                model_name = graph.edges[e].get('equipment_name')
                m = model.model_names[model_name]
                model.model_store.remove(m)

                ''' Remove the edge from the networkx graph, so we can check the result'''
                graph.remove_edge(*e)

                logger.debug(f'Removed first edge "{e}" and model ({model_name}) from cycle with {len(cycle)} edges and {len(edges)} removable candidates, cycle={cycle}')

        new_cycle_list = nx.algorithms.cycle_basis(graph)
        if len(new_cycle_list) > 0:
            logger.warning(f'{len(new_cycle_list)} of {len(cycle_list)} original cycles remaining in graph after {pass_count} passes removing trivial cycle edges')
        else:
            logger.info(f'All cycles removed from graph after {pass_count} passes. Huzzah!')
        cycle_list = new_cycle_list
        pass_count += 1

    cycles_removed = n_cycles_orig - len(new_cycle_list)
    conn = list(nx.connected_components(graph))
    if len(conn) > 1:
        # TODO Modify the associated model to match the disconnected subgraphs? Does this ever happen?
        logger.warning(f'After removing cycle-edges, graph has {len(conn)} disconnected subgraphs, returning all graphs.')
        graphs = []
        for idx, c in enumerate(conn):
            g = graph.subgraph(c)
            graphs.append(g)
        return graphs, type_df, cycles_removed
    else:
        return [graph], type_df, cycles_removed


def get_impedance_from_matrix(impedance_matrix):
    '''
    Gets lines impedances in ditto's format (R0, R1, X0, X1) a 3x3 impedance matrix in 'Kron reduced format'.
    This essentially solves Equation 13 from:
        W. H. Kersting and W. H. Phillips, "Distribution feeder line models," Proceedings of 1994 IEEE Rural Electric Power Conference, Colorado Springs, CO, USA, 1994, pp. A4/1-A4/8, doi: 10.1109/REPCON.1994.326257
    where `impedance-matrix` is `Zabc` and Z00=R0+X0j and Z11=R1+X1j are the first two diagonals from Z012.
    So we just solve [ZO12] = [A]^-1 [Zabc] [A] to get Z012, and pluck out the first two diagonal elements.
    :param impedance_matrix: Zabc from the paper (equivalent to ditto.models.Line.impedance_matrix)
    :return: R0, X0, R1. X1
    '''

    if np.shape(impedance_matrix) != (3, 3):
        raise ArithmeticError(f'Invalid impedance matrix found : {impedance_matrix}')

    from numpy import exp, pi, matrix, real, imag
    from numpy.linalg import inv
    alpha = exp((2 * pi) / 3j)
    a = matrix([[1, 1, 1],
                [1, alpha ** 2, alpha],
                [1, alpha, alpha ** 2]])

    # impedance_matrix = matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]] #for testing
    Zabc = impedance_matrix
    Z012 = a * Zabc * inv(a)

    Z00 = Z012[0, 0]
    Z11 = Z012[1, 1]
    R0 = round(real(Z00), 3)
    X0 = round(imag(Z00), 3)
    R1 = round(real(Z11), 3)
    X1 = round(imag(Z11), 3)
    return R0, X0, R1, X1


def set_low_priority():
    """ Set the priority of the process to below-normal.
        See https://stackoverflow.com/questions/1023038/change-process-priority-in-python-cross-platform
    """

    import sys, os
    try:
        sys.getwindowsversion()
    except AttributeError:
        isWindows = False
    else:
        isWindows = True

    if isWindows:
        p = psutil.Process(os.getpid())
        p.nice(psutil.IDLE_PRIORITY_CLASS)
    else:
        os.nice(1)


def set_normal_priority():
    """ Set the priority of the process to normal.
        See https://stackoverflow.com/questions/1023038/change-process-priority-in-python-cross-platform
    """

    import sys, os
    try:
        sys.getwindowsversion()
    except AttributeError:
        isWindows = False
    else:
        isWindows = True

    if isWindows:
        p = psutil.Process(os.getpid())
        p.nice(psutil.NORMAL_PRIORITY_CLASS)
    else:
        os.nice(0)


def set_high_priority():
    """ Set the priority of the process to normal.
        See https://stackoverflow.com/questions/1023038/change-process-priority-in-python-cross-platform
    """

    import sys, os
    try:
        sys.getwindowsversion()
    except AttributeError:
        isWindows = False
    else:
        isWindows = True

    if isWindows:
        p = psutil.Process(os.getpid())
        p.nice(psutil.HIGH_PRIORITY_CLASS)
    else:
        os.nice(-1)
