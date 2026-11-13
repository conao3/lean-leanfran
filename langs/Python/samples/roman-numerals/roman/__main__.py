from roman.numerals import roman

print(roman.toRoman(1994))
print(roman.fromRoman("MMXXVI"))
print(roman.fromRoman("hello"))
print(" ".join(roman.toRoman(n) for n in range(1, 11)))
