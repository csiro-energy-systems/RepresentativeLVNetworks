# Created by wes148 at 20/05/2021
from pathlib import Path
import os
from loguru import logger
# Set the working dir to the project root
proj_root = (Path(__file__) / '../../..').resolve()
os.chdir(proj_root.resolve())
logger.debug(f'Set working dir to {os.getcwd()}')
