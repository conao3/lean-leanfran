import pathlib

from wordcount.count import wc

text = (pathlib.Path(__file__).parent.parent / "sample.txt").read_text()
c = wc.count(text)
print(f"lines {c.lines}, words {c.words}, chars {c.chars}")
for w, n in wc.top(text, 3):
    print(w, n)
print(c.model_dump_json())
