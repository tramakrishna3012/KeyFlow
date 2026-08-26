import xml.etree.ElementTree as ET

tree = ET.parse('d:/Freelance/KeyFlow/demo_recordings/ui.xml')
for node in tree.getroot().iter('node'):
    text = node.attrib.get('text', '')
    desc = node.attrib.get('content-desc', '')
    bounds = node.attrib.get('bounds', '')
    if text or desc:
        safe_desc = desc.encode('ascii', 'replace').decode('ascii')
        print(f'Text: "{text}" | Desc: "{safe_desc}" | Bounds: {bounds}')

