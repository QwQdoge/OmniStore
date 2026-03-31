import subprocess
import re
import asyncio

class PacmanDownloader:
    def __init__(self, session=None):
        self.session = session

    