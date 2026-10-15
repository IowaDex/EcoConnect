import json
from pathlib import Path
from datetime import datetime, timezone
from graphify.detect import save_manifest
import glob

detect = json.loads(Path('graphify-out/.graphify_detect.json').read_text(encoding='utf-8'))
extract = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding='utf-8'))

# In --update mode, 'all_files' carries the full corpus; 'files' is the changed subset
_corpus = detect.get('all_files') or detect['files']

# Save manifest
manifest_files = {}
from graphify.cli import _stamped_manifest_files
_manifest_files = _stamped_manifest_files(_corpus, extract, Path(r'C:\Users\Nanao\Documents\EcoConnect'))

# Clean up - code files are always stamped, no semantic files extracted in this run
save_manifest(_manifest_files, root=r'C:\Users\Nanao\Documents\EcoConnect', scan_corpus={f for fl in _corpus.values() for f in fl}, clear_semantic=None)

# Update cost tracker
input_tok = extract.get('input_tokens', 0)
output_tok = extract.get('output_tokens', 0)

cost_path = Path('graphify-out/cost.json')
if cost_path.exists():
    cost = json.loads(cost_path.read_text(encoding="utf-8"))
else:
    cost = {'runs': [], 'total_input_tokens': 0, 'total_output_tokens': 0}

cost['runs'].append({
    'date': datetime.now(timezone.utc).isoformat(),
    'input_tokens': input_tok,
    'output_tokens': output_tok,
    'files': detect.get('total_files', 0),
})
cost['total_input_tokens'] += input_tok
cost['total_output_tokens'] += output_tok
cost_path.write_text(json.dumps(cost, indent=2, ensure_ascii=False), encoding="utf-8")

print(f'This run: {input_tok:,} input tokens, {output_tok:,} output tokens')
print(f'All time: {cost["total_input_tokens"]:,} input, {cost["total_output_tokens"]:,} output ({len(cost["runs"])} runs)')

# Clean up temp files
import os
for f in ['graphify-out/.graphify_detect.json', 'graphify-out/.graphify_extract.json', 'graphify-out/.graphify_ast.json',
          'graphify-out/.graphify_semantic.json', 'graphify-out/.graphify_analysis.json',
          'graphify-out/.graphify_merge.py', 'graphify-out/.graphify_build.py',
          'graphify-out/.graphify_label.py', 'graphify-out/.graphify_html.py',
          'graphify-out/.graphify_check_cache.py', 'graphify-out/.graphify_ast_extract.py']:
    try:
        Path(f).unlink(missing_ok=True)
    except:
        pass

# Clean up chunk files
for chunk in glob.glob('graphify-out/.graphify_chunk_*.json'):
    Path(chunk).unlink(missing_ok=True)

print("Cleanup complete")
