from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1];ns={'w':'http://schemas.microsoft.com/winfx/2006/xaml/presentation'}
def xaml(path):
 s=path.read_text(encoding='utf-8-sig');return ET.fromstring(s.split("[xml]$xaml=@'",1)[1].split("'@",1)[0])
a=xaml(root/'interface-windows/Interface.ps1');b=xaml(root/'setup-engineer/SetupView.ps1')
assert a.tag.endswith('Window') and b.tag.endswith('UserControl')
nav=next(n for n in a.iter() if n.attrib.get('{http://schemas.microsoft.com/winfx/2006/xaml}Name')=='Navigation')
assert [n.attrib['Header'] for n in nav]==['Chronométrage','Performances','Setup Engineer','Historique']
c=xaml(root/'ocr-windows/OcrView.ps1')
assert c.tag.endswith('UserControl')
for x in [a,b,c]:
 names=[n.attrib['{http://schemas.microsoft.com/winfx/2006/xaml}Name'] for n in x.iter() if '{http://schemas.microsoft.com/winfx/2006/xaml}Name' in n.attrib]
 assert len(names)==len(set(names))
assert 'ShowDialog' not in (root/'setup-engineer/SetupView.ps1').read_text(encoding='utf-8-sig').replace('$d.ShowDialog()', '')
assert 'SetupWindow.ps1' not in (root/'interface-windows/Interface.ps1').read_text(encoding='utf-8-sig')
print('PASS structure XML : une fenetre, vue integree, navigation, noms uniques')
