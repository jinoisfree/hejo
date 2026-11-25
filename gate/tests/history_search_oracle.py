"""Small Foundation search/snippet comparison; no app launch or load workload."""
import argparse
import asyncio
import json
from pathlib import Path
import subprocess
import tempfile
from gate.history_search import ranges, snippet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    pairs = [('Straße','STRASSE'),('café','CAFE'),('café','CAFE\u0301'),('İstanbul','istanbul'),
             ('Istanbul','ıstan'),('한글','한'),('ＡＢＣ','abc'),('æon','ae'),('👩🏽‍💻','👩'),
             ('σςΣ','σ'),('co\u00adoperate','cooperate'),('a\u0301','a'),('ﬃ','ffi'),
             ('ß','s'),('İ','i'),('e\u0301','é'),('가나다','가'),('👨‍👩‍👧','👩'),
             ('앞'*50+'검색'+'뒤'*50,'검색'),('abc\ndef ABC','ABC def'),('never matches','unfound')]
    rows = [{'text':text,'query':query,'locale':locale} for locale in ['en_US','ko_KR','tr_TR','de_DE'] for text,query in pairs]
    root = Path(__file__).resolve().parents[2]
    source = (root/'app/Sources/WorkspaceTools.swift').read_text()
    # Use the actual unchanged Swift implementations, ending before rendering and
    # model dependencies. Do not translate the expected snippet into Python.
    functions = source[source.index('    static func normalized'):source.index('    static func attributed')]
    program = 'import Foundation\nenum WorkspaceSearch {\n'+functions+'\n}\n'+r'''
let input = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let rows = try JSONSerialization.jsonObject(with: input) as! [[String:String]]
let result: [[String:Any]] = rows.map { row in
 let text=row["text"]!, query=row["query"]!, locale=Locale(identifier:row["locale"]!)
 return ["found":text.range(of:query,options:.caseInsensitive,locale:locale) != nil,
         "currentFound":text.localizedCaseInsensitiveContains(query),
         "snippet":WorkspaceSearch.snippet(text,query:query),"currentLocale":Locale.current.identifier]
}
print(String(data:try JSONSerialization.data(withJSONObject:result,options:.sortedKeys),encoding:.utf8)!)
'''
    with tempfile.TemporaryDirectory(prefix='hejo-search-oracle-') as folder:
        path=Path(folder);(path/'input.json').write_text(json.dumps(rows,ensure_ascii=False));(path/'main.swift').write_text(program)
        result=subprocess.run(['xcrun','swift',str(path/'main.swift'),str(path/'input.json')],capture_output=True,text=True)
        if result.returncode:
            raise RuntimeError('Foundation oracle failed; no results published')
        expected=json.loads(result.stdout)
    mismatches=[]
    for i,(row,wanted) in enumerate(zip(rows,expected,strict=True)):
        if bool(ranges(row['text'],row['query'],row['locale'])) != wanted['found']:
            mismatches.append({'case':i,'field':'found'})
        if bool(ranges(row['text'],row['query'],wanted['currentLocale'])) != wanted['currentFound']:
            mismatches.append({'case':i,'field':'currentFound'})
        if snippet(row['text'],row['query']) != wanted['snippet']:
            mismatches.append({'case':i,'field':'snippet'})
    args.output.write_text(json.dumps({'cases':rows,'expected':expected,'mismatches':mismatches,
                                      'comparisons':len(rows)*3,'type':'self-check'},ensure_ascii=False,indent=2)+'\n')
    print(f'{len(rows)*3} comparisons, {len(mismatches)} mismatches')
    if mismatches:raise SystemExit(1)


if __name__ == '__main__':
    main()
