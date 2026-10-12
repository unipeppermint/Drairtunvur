from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
entries={}
for path in (root/'Drairtunvur').rglob('*.swift'):
    for zh,en in re.findall(r'L\.text\(\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)',path.read_text()):
        if '\\(' in zh+en: continue
        zh=zh.replace('\\n','\n');en=en.replace('\\n','\n')
        entries[en]={'extractionState':'manual','localizations':{'en':{'stringUnit':{'state':'translated','value':en}},'zh-Hans':{'stringUnit':{'state':'translated','value':zh}}}}
(root/'Drairtunvur/Resources/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':entries,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
print(f'{len(entries)} bilingual catalog entries')
