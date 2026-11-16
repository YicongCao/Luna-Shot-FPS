"""Shared CLI roots for revision-aware audit/import/publishing tools."""
import argparse
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def parse():
 p=argparse.ArgumentParser();p.add_argument('--revision',choices=['ml07','ml09'],default='ml07');p.add_argument('--out');p.add_argument('--runtime');p.add_argument('--report-dir');a=p.parse_args();v=2 if a.revision=='ml09' else 1
 return a,R,Path(a.out or R/f'art_source/weapons/lc01/ls01-refine-v{v}'),Path(a.runtime or R/f'assets/weapons/lc01/ls01_v{v}'),Path(a.report_dir or R/f'docs/validation/ls01-refine-v{v}')
