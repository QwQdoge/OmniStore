from abc import ABC, abstractmethod


class SearchSource(ABC):
    def __init__(self, name: str, enabled: bool = True):
        self.name = name
        self.enabled = enabled

    @abstractmethod
    async def search(self, query: str) -> list:
        """所有子类必须实现这个方法，否则会报错"""

    def __str__(self):
        return f"{self.name} (Enabled: {self.enabled})"

    def __repr__(self):
        return f"<SearchSource name={self.name} enabled={self.enabled}>"
