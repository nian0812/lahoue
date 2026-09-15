from pathlib import Path
import json, shutil, hashlib
root=Path(r'D:\Game\LaHoue')
pack=root/'.work/final_asset_pack/LaHoue_Final_Asset_Pack'
# Keep existing assets omitted by this supplemental archive.
changes=[]
for src in (pack/'assets/lahoue_assets').rglob('*'):
    if not src.is_file(): continue
    dst=root/'assets/lahoue_assets'/src.relative_to(pack/'assets/lahoue_assets')
    if not dst.exists() or src.read_bytes()!=dst.read_bytes():
        if dst.exists():
            bak=root/'.work/before_final'/dst.relative_to(root)
            bak.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(dst,bak)
        dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dst)
        changes.append(str(dst.relative_to(root)))
(root/'reports/final_asset_import.json').write_text(json.dumps(changes,indent=2))
for name in ['README_FIRST.md','docs/FINAL_SCOPE.md','docs/ASSET_INTEGRATION_SPEC.md','docs/RUNTIME_STATE_MAP.json']:
    dst=root/'reports/final_scope'/name
    dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(pack/name,dst)
for src in (pack/'assets/lahoue_assets/manifests').rglob('*.json'):
    value=json.loads(src.read_text(encoding='utf-8'))
    if 'components' in value: print(src.name,[(x['semantic_id'],[x.get(k) for k in ['x','y','width','height']]) for x in value['components']])
print('Imported changed files:',len(changes))
