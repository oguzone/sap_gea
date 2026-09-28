"""SM30 tablo bakim (TMG) nesnelerini SAP'den disa aktarilmis gercek bir
ornekten (/MDPES/INVDET001, mdpgroup_invoice_de) uretir.

Kullanim: python gen_tmg.py <TABNAME> <hedef src klasoru>
Alan listesi hedef tablonun abapGit .tabl.xml dosyasindan okunur.
"""
import os
import re
import sys

TPL_DIR = r'C:\Users\MDP\Desktop\workspace\edonusum\mdpgroup_invoice_de\src'
TPL = '/MDPES/INVDET001'
TPL_FILE = '#mdpes#invdet001'
LF = chr(10)
CRLF = chr(13) + chr(10)

# Bilinen veri elemanlari -> (uzunluk, format, conv_exit, param_id)
KNOWN_ROLL = {
    'BUKRS': (4, 'CHAR', '', 'BUK'),
    'XFELD': (1, 'CHAR', '', ''),
    'SAKNR': (10, 'CHAR', 'ALPHA', 'SAK'),
    'MWSKZ': (2, 'CHAR', '', ''),
    'KOSTL': (10, 'CHAR', 'ALPHA', 'KOS'),
    'BLART': (2, 'CHAR', '', ''),
    'LIFNR': (10, 'CHAR', 'ALPHA', 'LIF'),
    'SEOCLSNAME': (30, 'CHAR', '', ''),
}


def read(path):
    raw = open(path, 'rb').read()
    return raw.decode('utf-8-sig').replace(CRLF, LF)


def write(path, text):
    with open(path, 'wb') as f:
        f.write(text.encode('utf-8'))


def table_fields(tabl_xml):
    s = read(tabl_xml)
    fields = []
    for m in re.finditer(r'<DD03P>(.*?)</DD03P>', s, re.S):
        b = m.group(1)

        def g(t):
            mm = re.search('<' + t + '>(.*?)</' + t + '>', b)
            return mm.group(1) if mm else ''

        name = g('FIELDNAME')
        if name == 'MANDT':
            continue
        roll = g('ROLLNAME')
        key = g('KEYFLAG') == 'X'
        if roll in KNOWN_ROLL:
            length, fmt, conv, pid = KNOWN_ROLL[roll]
        elif roll:
            raise SystemExit('Bilinmeyen veri elemani ' + roll + ' (' + name + ') - KNOWN_ROLL e ekleyin')
        else:
            length = int(g('LENG'))
            fmt = g('DATATYPE')
            conv, pid = '', ''
            if fmt == 'DEC':
                dec = int(g('DECIMALS') or 0)
                length = length + (1 if dec else 0) + 1   # ondalik ayrac + isaret
        fields.append(dict(name=name, key=key, len=length, fmt=fmt, conv=conv, pid=pid,
                           lower=g('LOWERCASE') == 'X'))
    return fields


def rename(text, tab):
    text = text.replace('/MDPES/SAPLINVDET001', 'SAPL' + tab)
    text = text.replace('/MDPES/LINVDET001', 'L' + tab)
    text = text.replace(TPL, tab)
    return text


def text_field(tab, f, col):
    mod = '4' if f['key'] else 'V'
    return (
        '      <RPY_DYFATC>\n'
        '       <CONT_TYPE>TABLE_CTRL</CONT_TYPE>\n'
        '       <CONT_NAME>TCTRL_%s</CONT_NAME>\n'
        '       <TYPE>TEXT</TYPE>\n'
        '       <NAME>*%s-%s</NAME>\n'
        '       <LINE>001</LINE>\n'
        '       <COLUMN>%03d</COLUMN>\n'
        '       <LENGTH>040</LENGTH>\n'
        '       <VISLENGTH>%03d</VISLENGTH>\n'
        '       <HEIGHT>001</HEIGHT>\n'
        '       <FORMAT>CHAR</FORMAT>\n'
        '       <FROM_DICT>X</FROM_DICT>\n'
        '       <MODIFIC>%s</MODIFIC>\n'
        '       <REQU_ENTRY>N</REQU_ENTRY>\n'
        '       <TC_HEADING>X</TC_HEADING>\n'
        '      </RPY_DYFATC>\n'
    ) % (tab, tab, f['name'], col, f['len'], mod)


def template_field(tab, f, col):
    ln = f['len']
    out = (
        '      <RPY_DYFATC>\n'
        '       <CONT_TYPE>TABLE_CTRL</CONT_TYPE>\n'
        '       <CONT_NAME>TCTRL_%s</CONT_NAME>\n'
        '       <TYPE>TEMPLATE</TYPE>\n'
        '       <NAME>%s-%s</NAME>\n'
        '       <TEXT>%s</TEXT>\n'
        '       <LINE>001</LINE>\n'
        '       <COLUMN>%03d</COLUMN>\n'
        '       <LENGTH>%03d</LENGTH>\n'
        '       <VISLENGTH>%03d</VISLENGTH>\n'
        '       <HEIGHT>001</HEIGHT>\n'
    ) % (tab, tab, f['name'], '_' * min(ln, 132), col, ln, ln)   # sablonda TEXT en fazla 132
    if f['key']:
        out += '       <GROUP1>KEY</GROUP1>\n'
    out += '       <FORMAT>%s</FORMAT>\n' % f['fmt']
    out += '       <FROM_DICT>X</FROM_DICT>\n'
    out += '       <MODIFIC>X</MODIFIC>\n'
    if f['conv']:
        out += '       <CONV_EXIT>%s</CONV_EXIT>\n' % f['conv']
    if f['pid']:
        out += '       <PARAM_ID>%s</PARAM_ID>\n' % f['pid']
    if f['lower']:
        out += '       <UP_LOWER>X</UP_LOWER>\n'
    if not f['key']:
        out += '       <INPUT_FLD>X</INPUT_FLD>\n'
    out += '       <OUTPUT_FLD>X</OUTPUT_FLD>\n'
    out += '       <REQU_ENTRY>N</REQU_ENTRY>\n'
    out += '      </RPY_DYFATC>\n'
    return out


def flow_logic(tab, fields):
    lines = ['PROCESS BEFORE OUTPUT.',
             ' MODULE LISTE_INITIALISIEREN.',
             ' LOOP AT EXTRACT WITH CONTROL',
             '  TCTRL_' + tab + ' CURSOR NEXTLINE.',
             '   MODULE LISTE_SHOW_LISTE.',
             ' ENDLOOP.',
             '*',
             'PROCESS AFTER INPUT.',
             ' MODULE LISTE_EXIT_COMMAND AT EXIT-COMMAND.',
             ' MODULE LISTE_BEFORE_LOOP.',
             ' LOOP AT EXTRACT.',
             '   MODULE LISTE_INIT_WORKAREA.',
             '   CHAIN.']
    lines += ['    FIELD ' + tab + '-' + f['name'] + ' .' for f in fields]
    lines += ['    MODULE SET_UPDATE_FLAG ON CHAIN-REQUEST.',
              '   ENDCHAIN.',
              '   FIELD VIM_MARKED MODULE LISTE_MARK_CHECKBOX.',
              '   CHAIN.']
    lines += ['    FIELD ' + tab + '-' + f['name'] + ' .' for f in fields if f['key']]
    lines += ['    MODULE LISTE_UPDATE_LISTE.',
              '   ENDCHAIN.',
              ' ENDLOOP.',
              ' MODULE LISTE_AFTER_LOOP.']
    return lines


def build_fugr_xml(text, tab, fields):
    text = rename(text, tab)
    open_tag = '     <FIELDS>\n'
    close_tag = '     </FIELDS>\n'
    a = text.index(open_tag) + len(open_tag)
    b = text.index(close_tag)
    items = re.findall(r'      <RPY_DYFATC>.*?</RPY_DYFATC>\n', text[a:b], re.S)
    fixed = [i for i in items if re.search(r'<NAME>(VIM_POSI_PUSH|VIM_POSITION_INFO|OK_CODE|VIM_FRAME_FIELD)</NAME>', i)]
    marked = [i for i in items if '<NAME>VIM_MARKED</NAME>' in i]
    assert len(fixed) == 4 and len(marked) == 1, (len(fixed), len(marked))
    body = ''.join(fixed)
    body += ''.join(text_field(tab, f, i + 1) for i, f in enumerate(fields))
    body += marked[0]
    body += ''.join(template_field(tab, f, i + 1) for i, f in enumerate(fields))
    # Eski abapGit icin akis mantigi XML icinde de (yeni surum ayri dosyayi kullanir)
    flow = ''.join('      <RPY_DYFLOW>\n       <LINE>' + l + '</LINE>\n      </RPY_DYFLOW>\n'
                   for l in flow_logic(tab, fields))
    return (text[:a] + body + close_tag + '     <FLOW_LOGIC>\n' + flow + '     </FLOW_LOGIC>\n'
            + text[b + len(close_tag):])


def main(tab, out_dir):
    low = tab.lower()
    tabl_xml = os.path.join(out_dir, low + '.tabl.xml')
    fields = table_fields(tabl_xml)
    ddtext = re.search(r'<DDTEXT>(.*?)</DDTEXT>', read(tabl_xml)).group(1)

    # 1) Fonksiyon grubu dosyalari (isim cevirerek)
    for fn in os.listdir(TPL_DIR):
        if not fn.startswith(TPL_FILE + '.fugr.') or fn.endswith('screen_0001.abap'):
            continue
        new_fn = (fn.replace('#mdpes#saplinvdet001', 'sapl' + low)
                    .replace('#mdpes#linvdet001', 'l' + low)
                    .replace(TPL_FILE, low))
        text = read(os.path.join(TPL_DIR, fn))
        if fn == TPL_FILE + '.fugr.xml':
            text = build_fugr_xml(text, tab, fields)
        else:
            text = rename(text, tab)
        write(os.path.join(out_dir, new_fn), text)

    # 2) Ekran akis mantigi (yeni abapGit formati - ayri dosya)
    write(os.path.join(out_dir, low + '.fugr.screen_0001.abap'), LF.join(flow_logic(tab, fields)) + LF)

    # 3) Bakim nesnesi (TOBJ)
    tobj = rename(read(os.path.join(TPL_DIR, TPL_FILE + 's.tobj.xml')), tab)
    tobj = re.sub(r'<DDTEXT>.*?</DDTEXT>', '<DDTEXT>' + ddtext + '</DDTEXT>', tobj)
    write(os.path.join(out_dir, low + 's.tobj.xml'), tobj)
    print(tab, 'alanlar:', [f['name'] for f in fields])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
