import collections
import logging
from pathlib import Path

from ditto.readers.opendss import OpenDSSReader
from ditto.store import Store

logger = logging.getLogger((__name__))

def read_dss(db_file: Path):
    store = Store()
    from datetime import datetime
    t0 = datetime.now()

    # logger.info(f'Started reading file: {db_file}')

    ''' OpenDSSDirect can't handle spaces in filenames unless you double-quote them. Welcome back to the 1980s.'''
    r = OpenDSSReader(
        master_file='"'+str(db_file.resolve())+'"',
        buscoordinates_file='"'+str(db_file.resolve()).replace('.dss','_buscoords.csv')+'"'
    )
    r.parse(store)
    store.set_names()
    store.name = db_file.name.split('.')[0] #use filename as network unique id

    store.inputh_file = str(db_file.resolve())

    types = [type(m).__name__ for m in store.model_store]
    logger.info(f'Finished reading network from {db_file.name} with {len(store.models)} models in {datetime.now() - t0}: with {collections.Counter(types)}')
    return [store]



