from pathlib import Path

from hatchling.builders.hooks.plugin.interface import BuildHookInterface


class CustomBuildHook(BuildHookInterface):
    def initialize(self, version, build_data):
        root = Path(self.root)
        license_file = root / "LICENSE"
        if not license_file.is_file():
            license_file = root.parent / "LICENSE"
        if not license_file.is_file():
            raise FileNotFoundError("The distribution requires the repository LICENSE")
        build_data["force_include"][str(license_file)] = "LICENSE"
