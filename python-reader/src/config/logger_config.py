import os
import sys

out_dir = "./output"

# See https://github.com/Delgan/loguru#suitable-for-scripts-and-libraries
# Usage:
# In a main function, configure using:
#   from loguru import logger
#   logger.configure(**logger_config.logging)
# Everywhere else, just import:
#   from loguru import logger
logging = {
    "handlers": [
        {"sink": sys.stdout, "level": "DEBUG", "diagnose": False, "format": "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | <level>{level: <8}</level> : <level>{message}</level> (<cyan>{name}:{thread.name}:pid-{process}</cyan> \"<cyan>{file.path}</cyan>:<cyan>{line}</cyan>\")"},
        {"sink": out_dir + "/log.log", "enqueue": True, "mode": "a+", "level": "DEBUG", "colorize": False, "serialize": True, "diagnose": False, "rotation": "10 MB", "compression": "zip"}
    ]
}