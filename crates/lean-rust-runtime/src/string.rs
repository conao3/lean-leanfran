//! `String`: UTF-8 bytes with a `'\0'` terminator, `m_size` bytes including it, `m_length`
//! code points. `String.Pos` is a byte offset.

use crate::array::lean_alloc_sarray;
use crate::nat::lean_usize_to_nat;
use crate::object::*;
use core::mem::{offset_of, size_of};
use core::ptr;

const STRING_DATA: usize = offset_of!(StringObject, m_data);

#[inline]
unsafe fn so(o: Obj) -> *mut StringObject {
    o as *mut StringObject
}

/* Allocation and access */

#[inline]
pub unsafe fn lean_alloc_string(size: usize, capacity: usize, len: usize) -> Obj {
    let o = lean_alloc_object(size_of::<StringObject>() + capacity);
    lean_set_st_header(o, LEAN_STRING as u32, 0);
    (*so(o)).m_size = size;
    (*so(o)).m_capacity = capacity;
    (*so(o)).m_length = len;
    o
}

#[inline]
pub unsafe fn lean_string_cstr(o: Obj) -> *const u8 {
    debug_check_live(o, "string read");
    (o as *const u8).add(STRING_DATA)
}

#[inline]
unsafe fn w_string_cstr(o: Obj) -> *mut u8 {
    (o as *mut u8).add(STRING_DATA)
}

/// Byte size including the terminator.
#[inline]
pub unsafe fn lean_string_size(o: Obj) -> usize {
    (*so(o)).m_size
}

/// Number of code points.
#[inline]
pub unsafe fn lean_string_len(o: Obj) -> usize {
    (*so(o)).m_length
}

#[inline]
pub unsafe fn lean_string_capacity(o: Obj) -> usize {
    (*so(o)).m_capacity
}

#[inline]
pub unsafe fn lean_string_byte_size(o: Obj) -> usize {
    size_of::<StringObject>() + lean_string_capacity(o)
}

/// The bytes of a string without the terminator.
#[inline]
pub unsafe fn lean_string_bytes<'a>(o: Obj) -> &'a [u8] {
    core::slice::from_raw_parts(lean_string_cstr(o), lean_string_size(o) - 1)
}

/// The contents of a string (borrowed; the string must stay alive while the result is used).
#[inline]
pub unsafe fn lean_string_to_str<'a>(o: Obj) -> &'a str {
    core::str::from_utf8_unchecked(lean_string_bytes(o))
}

#[inline]
pub fn lean_char_default_value() -> u32 {
    'A' as u32
}

/// A string from `sz` bytes of valid UTF-8 with `len` code points.
pub unsafe fn lean_mk_string_unchecked(s: &str, sz: usize, len: usize) -> Obj {
    mk_string_bytes_unchecked(&s.as_bytes()[..sz], len)
}

unsafe fn mk_string_bytes_unchecked(b: &[u8], len: usize) -> Obj {
    let rsz = b.len() + 1;
    let r = lean_alloc_string(rsz, rsz, len);
    ptr::copy_nonoverlapping(b.as_ptr(), w_string_cstr(r), b.len());
    *w_string_cstr(r).add(b.len()) = 0;
    r
}

/// A string from valid UTF-8 bytes.
pub unsafe fn lean_mk_string_from_bytes_unchecked(b: &[u8]) -> Obj {
    mk_string_bytes_unchecked(b, utf8_strlen(b))
}

/// A string from bytes; invalid sequences become U+FFFD.
pub unsafe fn lean_mk_string_from_bytes(b: &[u8]) -> Obj {
    match core::str::from_utf8(b) {
        Ok(s) => mk_string_bytes_unchecked(b, s.chars().count()),
        Err(_) => lean_mk_string(&String::from_utf8_lossy(b)),
    }
}

pub unsafe fn lean_mk_string(s: &str) -> Obj {
    mk_string_bytes_unchecked(s.as_bytes(), s.chars().count())
}

pub unsafe fn lean_mk_ascii_string_unchecked(s: &str) -> Obj {
    mk_string_bytes_unchecked(s.as_bytes(), s.len())
}

/* UTF-8 helpers */

pub(crate) fn utf8_strlen(b: &[u8]) -> usize {
    b.iter().filter(|&&c| (c & 0xc0) != 0x80).count()
}

#[inline]
fn is_utf8_first_byte(c: u8) -> bool {
    (c & 0x80) == 0 || (c & 0xe0) == 0xc0 || (c & 0xf0) == 0xe0 || (c & 0xf8) == 0xf0
}

/// UTF-8 encoding of a code point (`push_unicode_scalar`).
pub(crate) fn encode_utf8(c: u32, out: &mut Vec<u8>) {
    if c < 0x80 {
        out.push(c as u8);
    } else if c < 0x800 {
        out.push((0xc0 | (c >> 6)) as u8);
        out.push((0x80 | (c & 0x3f)) as u8);
    } else if c < 0x10000 {
        out.push((0xe0 | (c >> 12)) as u8);
        out.push((0x80 | ((c >> 6) & 0x3f)) as u8);
        out.push((0x80 | (c & 0x3f)) as u8);
    } else {
        out.push((0xf0 | (c >> 18)) as u8);
        out.push((0x80 | ((c >> 12) & 0x3f)) as u8);
        out.push((0x80 | ((c >> 6) & 0x3f)) as u8);
        out.push((0x80 | (c & 0x3f)) as u8);
    }
}

/// Decodes the code point at byte `i` of `s` (`lean_string_utf8_get_core`).
fn utf8_get_core(s: &[u8], i: usize) -> Option<u32> {
    let size = s.len();
    let c = s[i] as u32;
    if c & 0x80 == 0 {
        return Some(c);
    }
    if (c & 0xe0) == 0xc0 && i + 1 < size {
        let r = ((c & 0x1f) << 6) | (s[i + 1] as u32 & 0x3f);
        if r >= 0x80 {
            return Some(r);
        }
    }
    if (c & 0xf0) == 0xe0 && i + 2 < size {
        let r = ((c & 0x0f) << 12) | ((s[i + 1] as u32 & 0x3f) << 6) | (s[i + 2] as u32 & 0x3f);
        if r >= 0x800 && !(0xD800..=0xDFFF).contains(&r) {
            return Some(r);
        }
    }
    if (c & 0xf8) == 0xf0 && i + 3 < size {
        let r = ((c & 0x07) << 18)
            | ((s[i + 1] as u32 & 0x3f) << 12)
            | ((s[i + 2] as u32 & 0x3f) << 6)
            | (s[i + 3] as u32 & 0x3f);
        if (0x10000..=0x10FFFF).contains(&r) {
            return Some(r);
        }
    }
    None
}

/// Decodes all code points of valid UTF-8.
fn utf8_decode(s: &[u8]) -> Vec<u32> {
    let mut out = Vec::new();
    let mut i = 0;
    while i < s.len() {
        out.push(utf8_get_core(s, i).unwrap_or(lean_char_default_value()));
        i += utf8_char_size(s[i]);
    }
    out
}

#[inline]
fn utf8_char_size(c: u8) -> usize {
    if c & 0x80 == 0 {
        1
    } else if (c & 0xe0) == 0xc0 {
        2
    } else if (c & 0xf0) == 0xe0 {
        3
    } else if (c & 0xf8) == 0xf0 {
        4
    } else {
        1
    }
}

/// Validates UTF-8 as Lean does (no surrogates, at most U+10FFFF); returns the code point count.
pub(crate) fn validate_utf8(s: &[u8]) -> Option<usize> {
    core::str::from_utf8(s).ok().map(|t| t.chars().count())
}

/* Copies */

pub unsafe fn lean_copy_string(s: Obj, cap: usize) -> Obj {
    let sz = lean_string_size(s);
    let r = lean_alloc_string(sz, cap, lean_string_len(s));
    if (*s).m_other & LEAN_LINEAR_MARK_MASK != 0 {
        (*r).m_other |= LEAN_LINEAR_MARK_MASK;
    }
    ptr::copy_nonoverlapping(lean_string_cstr(s), w_string_cstr(r), sz);
    lean_dec_ref(s);
    r
}

pub unsafe fn lean_copy_string_nonlinear(s: Obj, cap: usize) -> Obj {
    lean_copy_string(s, cap)
}

#[inline]
pub unsafe fn lean_string_ensure_exclusive(s: Obj) -> Obj {
    if lean_is_exclusive(s) {
        s
    } else {
        lean_copy_string(s, lean_string_capacity(s))
    }
}

unsafe fn string_ensure_capacity(o: Obj, extra: usize) -> Obj {
    let sz = lean_string_size(o);
    let cap = lean_string_capacity(o);
    if sz + extra > cap {
        let r = lean_alloc_string(sz, cap + sz + extra, lean_string_len(o));
        (*r).m_other = (*o).m_other;
        ptr::copy_nonoverlapping(lean_string_cstr(o), w_string_cstr(r), sz);
        lean_dealloc(o, lean_string_byte_size(o));
        r
    } else {
        o
    }
}

/// Appends `bytes` (with `len` code points) to the owned string `s`.
unsafe fn string_append_bytes(s: Obj, bytes: &[u8], len: usize) -> Obj {
    let sz = lean_string_size(s);
    let new_sz = sz + bytes.len();
    let r = if !lean_is_exclusive(s) {
        lean_copy_string(s, new_sz * 2)
    } else {
        string_ensure_capacity(s, bytes.len())
    };
    ptr::copy_nonoverlapping(bytes.as_ptr(), w_string_cstr(r).add(sz - 1), bytes.len());
    (*so(r)).m_size = new_sz;
    (*so(r)).m_length += len;
    *w_string_cstr(r).add(new_sz - 1) = 0;
    r
}

/* Operations */

pub unsafe fn lean_string_push(s: Obj, c: u32) -> Obj {
    let mut buf = Vec::with_capacity(4);
    encode_utf8(c, &mut buf);
    string_append_bytes(s, &buf, 1)
}

/// Consumes `s1`, borrows `s2`.
pub unsafe fn lean_string_append(s1: Obj, s2: Obj) -> Obj {
    let len2 = lean_string_len(s2);
    if s1 == s2 {
        let b = lean_string_bytes(s2).to_vec();
        return string_append_bytes(s1, &b, len2);
    }
    string_append_bytes(s1, lean_string_bytes(s2), len2)
}

#[inline]
pub unsafe fn lean_string_length(s: Obj) -> Obj {
    lean_box(lean_string_len(s))
}

#[inline]
pub unsafe fn lean_string_utf8_byte_size(s: Obj) -> Obj {
    lean_box(lean_string_size(s) - 1)
}

/// `String.ofList` (consumes the list).
pub unsafe fn lean_string_mk(cs: Obj) -> Obj {
    let mut bytes = Vec::new();
    let mut len = 0;
    let mut o = cs;
    while !lean_is_scalar(o) {
        encode_utf8(lean_unbox_uint32(lean_ctor_get(o, 0)), &mut bytes);
        o = lean_ctor_get(o, 1);
        len += 1;
    }
    lean_dec(cs);
    mk_string_bytes_unchecked(&bytes, len)
}

/// The list of characters of a string (consumes it).
pub unsafe fn lean_string_data(s: Obj) -> Obj {
    let cs = utf8_decode(lean_string_bytes(s));
    lean_dec_ref(s);
    let mut r = lean_box(0);
    for c in cs.into_iter().rev() {
        let n = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(n, 0, lean_box_uint32(c));
        lean_ctor_set(n, 1, r);
        r = n;
    }
    r
}

pub unsafe fn lean_string_utf8_get(s: Obj, i0: Obj) -> u32 {
    if !lean_is_scalar(i0) {
        return lean_char_default_value();
    }
    let i = lean_unbox(i0);
    let b = lean_string_bytes(s);
    if i >= b.len() {
        return lean_char_default_value();
    }
    utf8_get_core(b, i).unwrap_or(lean_char_default_value())
}

#[inline]
pub unsafe fn lean_string_utf8_get_fast(s: Obj, i: Obj) -> u32 {
    let b = lean_string_bytes(s);
    let idx = lean_unbox(i);
    let c = *lean_string_cstr(s).add(idx);
    if c & 0x80 == 0 {
        return c as u32;
    }
    utf8_get_core(b, idx).unwrap_or(lean_char_default_value())
}

pub unsafe fn lean_string_utf8_get_opt(s: Obj, i0: Obj) -> Obj {
    if !lean_is_scalar(i0) {
        return lean_box(0);
    }
    let i = lean_unbox(i0);
    let b = lean_string_bytes(s);
    if i >= b.len() {
        return lean_box(0);
    }
    match utf8_get_core(b, i) {
        Some(c) => {
            let r = lean_alloc_ctor(1, 1, 0);
            lean_ctor_set(r, 0, lean_box_uint32(c));
            r
        }
        None => lean_box(0),
    }
}

pub unsafe fn lean_string_utf8_get_bang(s: Obj, i0: Obj) -> u32 {
    let b = lean_string_bytes(s);
    let ok = if lean_is_scalar(i0) && lean_unbox(i0) < b.len() {
        utf8_get_core(b, lean_unbox(i0))
    } else {
        None
    };
    match ok {
        Some(c) => c,
        None => {
            crate::panic::lean_panic_fn(
                lean_box(0),
                lean_mk_ascii_string_unchecked("Error: invalid `String.Pos` at `String.get!`"),
            );
            lean_char_default_value()
        }
    }
}

pub unsafe fn lean_string_utf8_next(s: Obj, i0: Obj) -> Obj {
    if !lean_is_scalar(i0) {
        return crate::nat::lean_nat_add(i0, lean_box(1));
    }
    let i = lean_unbox(i0);
    let b = lean_string_bytes(s);
    if i >= b.len() {
        return lean_usize_to_nat(i + 1);
    }
    lean_box(i + utf8_char_size(b[i]))
}

#[inline]
pub unsafe fn lean_string_utf8_next_fast(s: Obj, i: Obj) -> Obj {
    let idx = lean_unbox(i);
    let c = *lean_string_cstr(s).add(idx);
    lean_box(idx + utf8_char_size(c))
}

pub unsafe fn lean_string_utf8_prev(s: Obj, i0: Obj) -> Obj {
    if !lean_is_scalar(i0) {
        return crate::nat::lean_nat_sub(i0, lean_box(1));
    }
    let mut i = lean_unbox(i0);
    let b = lean_string_bytes(s);
    if i == 0 {
        return lean_box(0);
    }
    if i > b.len() {
        return lean_box(i - 1);
    }
    i -= 1;
    while !is_utf8_first_byte(b[i]) {
        i -= 1;
    }
    lean_box(i)
}

pub unsafe fn lean_string_is_valid_pos(s: Obj, i0: Obj) -> u8 {
    if !lean_is_scalar(i0) {
        return 0;
    }
    let i = lean_unbox(i0);
    let b = lean_string_bytes(s);
    if i > b.len() {
        return 0;
    }
    if i == b.len() {
        return 1;
    }
    is_utf8_first_byte(b[i]) as u8
}

#[inline]
pub unsafe fn lean_string_utf8_at_end(s: Obj, i: Obj) -> u8 {
    (!lean_is_scalar(i) || lean_unbox(i) >= lean_string_size(s) - 1) as u8
}

pub unsafe fn lean_string_utf8_extract(s: Obj, b0: Obj, e0: Obj) -> Obj {
    let b = if lean_is_scalar(b0) {
        lean_unbox(b0)
    } else {
        usize::MAX
    };
    let mut e = if lean_is_scalar(e0) {
        lean_unbox(e0)
    } else {
        usize::MAX
    };
    let bytes = lean_string_bytes(s);
    let sz = bytes.len();
    if b >= e || b >= sz {
        return lean_mk_string_unchecked("", 0, 0);
    }
    if !is_utf8_first_byte(bytes[b]) {
        return lean_mk_string_unchecked("", 0, 0);
    }
    if e > sz {
        e = sz;
    }
    if e < sz && !is_utf8_first_byte(bytes[e]) {
        e = sz;
    }
    lean_mk_string_from_bytes_unchecked(&bytes[b..e])
}

pub unsafe fn lean_string_utf8_extract_fast(s: Obj, b0: Obj, e0: Obj) -> Obj {
    let b = lean_unbox(b0);
    let e = lean_unbox(e0);
    if b >= e {
        return lean_mk_string_unchecked("", 0, 0);
    }
    lean_mk_string_from_bytes_unchecked(&lean_string_bytes(s)[b..e])
}

/// Consumes `s`, borrows `i0`.
pub unsafe fn lean_string_utf8_set(s: Obj, i0: Obj, c: u32) -> Obj {
    if !lean_is_scalar(i0) {
        return s;
    }
    let i = lean_unbox(i0);
    let sz = lean_string_size(s) - 1;
    if i >= sz {
        return s;
    }
    let old = *lean_string_cstr(s).add(i);
    if old < 128 && c < 128 {
        let r = lean_string_ensure_exclusive(s);
        *w_string_cstr(r).add(i) = c as u8;
        return r;
    }
    if !is_utf8_first_byte(old) {
        return s;
    }
    let mut bytes = lean_string_bytes(s).to_vec();
    let len = lean_string_len(s);
    let marked = (*s).m_other & LEAN_LINEAR_MARK_MASK;
    lean_dec(s);
    let mut tmp = Vec::new();
    encode_utf8(c, &mut tmp);
    let old_sz = utf8_char_size(old).min(bytes.len() - i);
    bytes.splice(i..i + old_sz, tmp);
    let r = mk_string_bytes_unchecked(&bytes, len);
    (*r).m_other |= marked;
    r
}

#[inline]
pub unsafe fn lean_string_get_byte_fast(s: Obj, i: Obj) -> u8 {
    *lean_string_cstr(s).add(lean_unbox(i))
}

#[inline]
pub unsafe fn lean_string_uget_byte_fast(s: Obj, i: usize) -> u8 {
    *lean_string_cstr(s).add(i)
}

/* Comparison and hashing */

#[inline]
pub unsafe fn lean_string_eq(s1: Obj, s2: Obj) -> bool {
    s1 == s2
        || (lean_string_size(s1) == lean_string_size(s2)
            && lean_string_bytes(s1) == lean_string_bytes(s2))
}

#[inline]
pub unsafe fn lean_string_ne(s1: Obj, s2: Obj) -> bool {
    !lean_string_eq(s1, s2)
}

#[inline]
pub unsafe fn lean_string_dec_eq(s1: Obj, s2: Obj) -> u8 {
    lean_string_eq(s1, s2) as u8
}

pub unsafe fn lean_string_lt(s1: Obj, s2: Obj) -> bool {
    lean_string_bytes(s1) < lean_string_bytes(s2)
}

#[inline]
pub unsafe fn lean_string_dec_lt(s1: Obj, s2: Obj) -> u8 {
    lean_string_lt(s1, s2) as u8
}

/// `compare` as an `Ordering` constructor index (0 lt, 1 eq, 2 gt).
pub unsafe fn lean_string_compare(s1: Obj, s2: Obj) -> u8 {
    match lean_string_bytes(s1).cmp(lean_string_bytes(s2)) {
        core::cmp::Ordering::Less => 0,
        core::cmp::Ordering::Equal => 1,
        core::cmp::Ordering::Greater => 2,
    }
}

/// MurmurHash64A of the bytes, as `hash_str` in `hash.cpp`.
pub fn murmur_hash_64a(key: &[u8], seed: u64) -> u64 {
    const M: u64 = 0xc6a4a7935bd1e995;
    const R: u32 = 47;
    let len = key.len();
    let mut h = seed ^ (len as u64).wrapping_mul(M);
    let (chunks, rest) = key.as_chunks::<8>();
    for chunk in chunks {
        let mut k = u64::from_le_bytes(*chunk);
        k = k.wrapping_mul(M);
        k ^= k >> R;
        k = k.wrapping_mul(M);
        h ^= k;
        h = h.wrapping_mul(M);
    }
    if !rest.is_empty() {
        for (i, b) in rest.iter().enumerate() {
            h ^= (*b as u64) << (8 * i);
        }
        h = h.wrapping_mul(M);
    }
    h ^= h >> R;
    h = h.wrapping_mul(M);
    h ^= h >> R;
    h
}

pub unsafe fn lean_string_hash(s: Obj) -> u64 {
    murmur_hash_64a(lean_string_bytes(s), 11)
}

pub unsafe fn lean_string_of_usize(n: usize) -> Obj {
    lean_mk_ascii_string_unchecked(&n.to_string())
}

pub unsafe fn lean_string_memcmp(s1: Obj, s2: Obj, lstart: Obj, rstart: Obj, len: Obj) -> u8 {
    let (l, r, n) = (lean_unbox(lstart), lean_unbox(rstart), lean_unbox(len));
    let a = core::slice::from_raw_parts(lean_string_cstr(s1).add(l), n);
    let b = core::slice::from_raw_parts(lean_string_cstr(s2).add(r), n);
    (a == b) as u8
}

/* Conversions with `ByteArray` */

pub unsafe fn lean_string_to_utf8(s: Obj) -> Obj {
    let b = lean_string_bytes(s);
    let r = lean_alloc_sarray(1, b.len(), b.len());
    ptr::copy_nonoverlapping(b.as_ptr(), crate::array::lean_sarray_cptr(r), b.len());
    r
}

/// Consumes the byte array.
pub unsafe fn lean_string_from_utf8_unchecked(a: Obj) -> Obj {
    let r = lean_mk_string_from_bytes_unchecked(crate::array::sarray_bytes(a));
    lean_dec(a);
    r
}

pub unsafe fn lean_string_validate_utf8(a: Obj) -> u8 {
    validate_utf8(crate::array::sarray_bytes(a)).is_some() as u8
}

pub unsafe fn lean_decode_lossy_utf8(a: Obj) -> Obj {
    lean_mk_string_from_bytes(crate::array::sarray_bytes(a))
}

/* Slices (`String.Slice`: string, start byte, end byte) */

unsafe fn slice_bytes<'a>(slice: Obj) -> &'a [u8] {
    let s = lean_ctor_get(slice, 0);
    let b = lean_unbox(lean_ctor_get(slice, 1));
    let e = lean_unbox(lean_ctor_get(slice, 2));
    core::slice::from_raw_parts(lean_string_cstr(s).add(b), e - b)
}

pub unsafe fn lean_slice_hash(s: Obj) -> u64 {
    murmur_hash_64a(slice_bytes(s), 11)
}

pub unsafe fn lean_slice_dec_lt(s1: Obj, s2: Obj) -> u8 {
    (slice_bytes(s1) < slice_bytes(s2)) as u8
}
