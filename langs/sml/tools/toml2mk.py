#!/usr/bin/env python3
import sys

def _load_toml(path):
    try:
        import tomllib as tomli  # Python 3.11+
    except ModuleNotFoundError:
        import tomli as tomli  # type: ignore
    with open(path, "rb") as f:
        return tomli.load(f)

def shjoin(xs):
    return " ".join(xs)

def main():
    proj_file = sys.argv[1] if len(sys.argv) > 1 else "Project.toml"
    data = _load_toml(proj_file)

    project = data.get("project", {})
    bins = data.get("bin", [])
    mlb = data.get("mlb", {})
    tool_mlton = data.get("tool", {}).get("mlton", {})
    common_flags = tool_mlton.get("common_flags", [])
    dev_flags = tool_mlton.get("dev_flags", [])
    test_flags = tool_mlton.get("test_flags", [])
    prod_flags = tool_mlton.get("prod_flags", [])
    test_flags = tool_mlton.get("test_flags", [])

    bin_names = [b["name"] for b in bins]
    profiles_by_bin = {}
    for b in bin_names:
        table = mlb.get(b, {})
        profiles = sorted([k for k in table.keys() if k != "base"])
        profiles_by_bin[b] = profiles

    print(f'PROJECT_NAME := {project.get("name","")}')
    print(f'PROJECT_VERSION := {project.get("version","")}')
    print(f'BINS := {" ".join(bin_names)}')
    print(f'MLTON_COMMON_FLAGS := {shjoin(common_flags)}')
    print(f'MLTON_DEV_FLAGS := {shjoin(dev_flags)}')
    print(f'MLTON_TEST_FLAGS := {shjoin(test_flags)}')
    print(f'MLTON_PROD_FLAGS := {shjoin(prod_flags)}')
    all_profiles = sorted({p for b in bin_names for p in profiles_by_bin[b]})
    print(f'PROFILES := {" ".join(all_profiles)}')

    def up(s): return s.upper().replace("-", "_")
    for b in bin_names:
        table = mlb.get(b, {})
        profiles = profiles_by_bin[b]
        print(f'{up(b)}_PROFILES := {" ".join(profiles)}')
        base = table.get("base", "")
        if base:
            print(f'{up(b)}_BASE_MLB := {base}')
        for p in profiles:
            path = table[p]
            print(f'{up(b)}_MLB_{p} := {path}')

    for b in bins:
        if "out_name" in b:
            print(f'{up(b["name"])}_OUT_NAME := {b["out_name"]}')

if __name__ == "__main__":
    main()
