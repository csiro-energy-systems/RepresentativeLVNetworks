# Created by wes148 at 15/03/2021

from __future__ import absolute_import, division, print_function
from builtins import super, range, zip, round, map

import logging
import os
import argparse
import opendssdirect as dss
from opendssdirect.utils import run_command
from pathlib import Path
import pandas as pd

logger = logging.getLogger(__name__)
import networkx as nx
import matplotlib.pyplot as plt


def run_opendss_power_flow(path_to_master, path_to_export):
    '''
    Example code for runnings very basic power flow simulations using OpenDSS.

    All:
    - Master.dss: remove all 'phases=3' strings
    - Linecode.dss: remove CO/C1 or (CMatrix)
    - Lines.dss: maybe remove 'phases=3'.  Might not matter though.

    Run OpenDSS power flow on given feeder.
    Note: This relies on Opendssdirect.py (run: `pip install OpenDSSDirect.py[extras]==0.6.1`)

    :param path_to_master:
    :param path_to_export:
    :return: A Dataframe constructed from reading  the simulated voltage_profile.csv, or and empty DataFrame if the simulation failed.
    :raise ChildProcessError if the simulation was unsuccessful.
    '''
    in_file = str((Path(path_to_master) / 'master.dss').resolve())
    voltage_out_file = str(Path(path_to_export) / 'voltage_profile.csv')
    Path(path_to_export).mkdir(parents=True, exist_ok=True)
    line_out_file = f'{path_to_export}\\line_profile.csv'
    line_plot_file = f'{path_to_export}\\line_plot.png'

    cmd = f'redirect {in_file}'
    redir_result = run_command(cmd)

    dss.Circuit.FirstElement()
    buses = dss.Circuit.AllBusNames()
    trans = dss.Transformers.AllNames()
    pdes = dss.PDElements.AllNames()

    ''' Need to add an EnergyMeter at the network source for the DSS distance calcs to work. '''
    # TODO confirm whether the first PD Element is always the right location for the meter?!
    meter_result = None
    if buses != [] and trans != [] and buses[0] == trans[0]:
        ''' Special case: if a transformer is actually the first bus, we have to prefix 'Transformer.' to its name '''
        meter_result = run_command(f'New EnergyMeter.Main Transformer.{trans[0]}')
    elif pdes != []:
        ''' Otherwise, just add the EnergyMeter to the first Line '''
        meter_result = run_command(f'New EnergyMeter.Main {pdes[0]}')

    solve_result = dss.run_command("Solve")

    if redir_result != '' or solve_result != '':
        raise ChildProcessError(f'Error returned from OpenDSSDirect simulation. \nRedirect: {redir_result}\nSet_Meter: {meter_result}\nSolve: {solve_result}')
    else:
        logger.debug(f'OpenDSSDirect simulation from {in_file} completed.')
        run_command(f'Export voltages {voltage_out_file}')
        df_voltages = pd.read_csv(voltage_out_file)
        df_lines = dss.utils.lines_to_dataframe()
        df_lines.to_csv(line_out_file)

        G, pos = create_graph(df_lines, phase=1)
        fig = plot_graph(G, pos)
        plt.savefig(line_plot_file)
        # plt.ion()
        plt.show(block=False)
        # plt.pause(0.001)

        logger.debug(f'Voltages:\n{df_voltages.to_string()}')
        logger.debug(f'Lines:\n{df_lines.to_string()}')

        return df_voltages, df_lines


def plot_graph(G, pos):
    '''
    Plots a networkx model created by create_graph()
    :param G:
    :param pos:
    :return: the figure object
    '''
    fig, axs = plt.subplots(1, 1, figsize=(16, 10))
    ax = axs
    nx.draw_networkx_nodes(G, pos, ax=ax, label={x: x for x in G.nodes()})
    nx.draw_networkx_labels(G, pos, ax=ax, labels={x: x for x in G.nodes()})
    nx.draw_networkx_edges(G, pos, ax=ax, label={x: x for x in G.nodes()})
    ax.grid()

    ax.set_ylabel("Voltage in p.u.")
    ax.set_xlabel("Distances in km")
    ax.set_title("Voltage profile plot for phase A");
    return fig


def create_graph(df, phase=1):
    '''
    Creates a networkx graph from a dss Line dataframe.
    :param df:
    :param phase:
    :return:
    '''
    G = nx.Graph()

    data = df[['Bus1', 'Bus2']].to_dict(orient="index")

    for name in data:
        line = data[name]
        if f".{phase}" in line["Bus1"] and f".{phase}" in line["Bus2"]:
            G.add_edge(line["Bus1"].split(".")[0], line["Bus2"].split(".")[0])

    pos = {}
    for name in dss.Circuit.AllBusNames():
        dss.Circuit.SetActiveBus(f"{name}")
        if phase in dss.Bus.Nodes():
            index = dss.Bus.Nodes().index(phase)
            re, im = dss.Bus.PuVoltage()[index:index + 2]
            V = abs(complex(re, im))
            D = dss.Bus.Distance()

            pos[dss.Bus.Name()] = (D, V)

    return G, pos
