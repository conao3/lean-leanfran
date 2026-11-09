// Lean compiler output
// Module: LeanPythonEmbed.roman.numerals.roman
// Imports: public import Init public meta import Init
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
uint8_t lean_uint32_dec_eq(uint32_t, uint32_t);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
lean_object* lean_string_append(lean_object*, lean_object*);
lean_object* lean_string_utf8_byte_size(lean_object*);
lean_object* lean_string_data(lean_object*);
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "M"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__0_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(1000) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__0_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__1 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__1_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "CM"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__2 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__2_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(900) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__2_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__3 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__3_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "D"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__4 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__4_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(500) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__4_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__5 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__5_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "CD"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__6 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__6_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(400) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__6_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__7 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__7_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "C"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__8 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__8_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(100) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__8_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__9 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__9_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "XC"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__10 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__10_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(90) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__10_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__11 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__11_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "L"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__12 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__12_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(50) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__12_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__13 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__13_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__14_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "XL"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__14 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__14_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__15_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(40) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__14_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__15 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__15_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__16_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "X"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__16 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__16_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__17_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(10) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__16_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__17 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__17_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__18_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "IX"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__18 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__18_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__19_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(9) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__18_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__19 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__19_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__20_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "V"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__20 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__20_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__21_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(5) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__20_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__21 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__21_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__22_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "IV"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__22 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__22_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__23_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(4) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__22_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__23 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__23_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__24_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "I"};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__24 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__24_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__25_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(1) << 1) | 1)),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__24_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__25 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__25_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__26_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__25_value),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__26 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__26_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__27_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__23_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__26_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__27 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__27_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__28_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__21_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__27_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__28 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__28_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__29_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__19_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__28_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__29 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__29_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__30_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__17_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__29_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__30 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__30_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__31_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__15_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__30_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__31 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__31_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__32_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__13_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__31_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__32 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__32_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__33_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__11_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__32_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__33 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__33_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__34_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__9_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__33_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__34 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__34_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__35_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__7_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__34_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__35 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__35_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__36_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__5_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__35_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__36 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__36_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__37_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__3_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__36_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__37 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__37_value;
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__38_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__1_value),((lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__37_value)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__38 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__38_value;
LEAN_EXPORT const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals___closed__38_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 1, .m_capacity = 1, .m_length = 0, .m_data = ""};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___closed__0_value;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_toRoman(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_toRoman___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value(uint32_t);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value___boxed(lean_object*);
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 1}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___closed__0_value;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_fromRoman(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux(lean_object* v_x_94_, lean_object* v_x_95_, lean_object* v_x_96_){
_start:
{
lean_object* v_zero_97_; uint8_t v_isZero_98_; 
v_zero_97_ = lean_unsigned_to_nat(0u);
v_isZero_98_ = lean_nat_dec_eq(v_x_94_, v_zero_97_);
if (v_isZero_98_ == 1)
{
lean_object* v___x_99_; 
lean_dec(v_x_95_);
lean_dec(v_x_94_);
v___x_99_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___closed__0));
return v___x_99_;
}
else
{
if (lean_obj_tag(v_x_95_) == 0)
{
lean_object* v___x_100_; 
lean_dec(v_x_94_);
v___x_100_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___closed__0));
return v___x_100_;
}
else
{
lean_object* v_head_101_; lean_object* v_tail_102_; lean_object* v_fst_103_; lean_object* v_snd_104_; lean_object* v_one_105_; lean_object* v_n_106_; uint8_t v___x_107_; 
v_head_101_ = lean_ctor_get(v_x_95_, 0);
v_tail_102_ = lean_ctor_get(v_x_95_, 1);
v_fst_103_ = lean_ctor_get(v_head_101_, 0);
v_snd_104_ = lean_ctor_get(v_head_101_, 1);
lean_inc(v_snd_104_);
v_one_105_ = lean_unsigned_to_nat(1u);
v_n_106_ = lean_nat_sub(v_x_94_, v_one_105_);
lean_dec(v_x_94_);
v___x_107_ = lean_nat_dec_le(v_fst_103_, v_x_96_);
if (v___x_107_ == 0)
{
lean_inc(v_tail_102_);
lean_dec(v_snd_104_);
lean_dec_ref_known(v_x_95_, 2);
v_x_94_ = v_n_106_;
v_x_95_ = v_tail_102_;
goto _start;
}
else
{
lean_object* v___x_109_; lean_object* v___x_110_; lean_object* v___x_111_; 
v___x_109_ = lean_nat_sub(v_x_96_, v_fst_103_);
v___x_110_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux(v_n_106_, v_x_95_, v___x_109_);
lean_dec(v___x_109_);
v___x_111_ = lean_string_append(v_snd_104_, v___x_110_);
lean_dec_ref(v___x_110_);
return v___x_111_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux___boxed(lean_object* v_x_112_, lean_object* v_x_113_, lean_object* v_x_114_){
_start:
{
lean_object* v_res_115_; 
v_res_115_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux(v_x_112_, v_x_113_, v_x_114_);
lean_dec(v_x_114_);
return v_res_115_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_toRoman(lean_object* v_n_116_){
_start:
{
lean_object* v___x_117_; lean_object* v___x_118_; lean_object* v___x_119_; lean_object* v___x_120_; 
v___x_117_ = lean_unsigned_to_nat(13u);
v___x_118_ = lean_nat_add(v_n_116_, v___x_117_);
v___x_119_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_numerals));
v___x_120_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_toRomanAux(v___x_118_, v___x_119_, v_n_116_);
return v___x_120_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_toRoman___boxed(lean_object* v_n_121_){
_start:
{
lean_object* v_res_122_; 
v_res_122_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_toRoman(v_n_121_);
lean_dec(v_n_121_);
return v_res_122_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value(uint32_t v_x_123_){
_start:
{
uint32_t v___x_124_; uint8_t v___x_125_; 
v___x_124_ = 73;
v___x_125_ = lean_uint32_dec_eq(v_x_123_, v___x_124_);
if (v___x_125_ == 0)
{
uint32_t v___x_126_; uint8_t v___x_127_; 
v___x_126_ = 86;
v___x_127_ = lean_uint32_dec_eq(v_x_123_, v___x_126_);
if (v___x_127_ == 0)
{
uint32_t v___x_128_; uint8_t v___x_129_; 
v___x_128_ = 88;
v___x_129_ = lean_uint32_dec_eq(v_x_123_, v___x_128_);
if (v___x_129_ == 0)
{
uint32_t v___x_130_; uint8_t v___x_131_; 
v___x_130_ = 76;
v___x_131_ = lean_uint32_dec_eq(v_x_123_, v___x_130_);
if (v___x_131_ == 0)
{
uint32_t v___x_132_; uint8_t v___x_133_; 
v___x_132_ = 67;
v___x_133_ = lean_uint32_dec_eq(v_x_123_, v___x_132_);
if (v___x_133_ == 0)
{
uint32_t v___x_134_; uint8_t v___x_135_; 
v___x_134_ = 68;
v___x_135_ = lean_uint32_dec_eq(v_x_123_, v___x_134_);
if (v___x_135_ == 0)
{
uint32_t v___x_136_; uint8_t v___x_137_; 
v___x_136_ = 77;
v___x_137_ = lean_uint32_dec_eq(v_x_123_, v___x_136_);
if (v___x_137_ == 0)
{
lean_object* v___x_138_; 
v___x_138_ = lean_unsigned_to_nat(0u);
return v___x_138_;
}
else
{
lean_object* v___x_139_; 
v___x_139_ = lean_unsigned_to_nat(1000u);
return v___x_139_;
}
}
else
{
lean_object* v___x_140_; 
v___x_140_ = lean_unsigned_to_nat(500u);
return v___x_140_;
}
}
else
{
lean_object* v___x_141_; 
v___x_141_ = lean_unsigned_to_nat(100u);
return v___x_141_;
}
}
else
{
lean_object* v___x_142_; 
v___x_142_ = lean_unsigned_to_nat(50u);
return v___x_142_;
}
}
else
{
lean_object* v___x_143_; 
v___x_143_ = lean_unsigned_to_nat(10u);
return v___x_143_;
}
}
else
{
lean_object* v___x_144_; 
v___x_144_ = lean_unsigned_to_nat(5u);
return v___x_144_;
}
}
else
{
lean_object* v___x_145_; 
v___x_145_ = lean_unsigned_to_nat(1u);
return v___x_145_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value___boxed(lean_object* v_x_146_){
_start:
{
uint32_t v_x_194__boxed_147_; lean_object* v_res_148_; 
v_x_194__boxed_147_ = lean_unbox_uint32(v_x_146_);
lean_dec(v_x_146_);
v_res_148_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value(v_x_194__boxed_147_);
return v_res_148_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(lean_object* v_x_151_){
_start:
{
if (lean_obj_tag(v_x_151_) == 0)
{
lean_object* v___x_152_; 
v___x_152_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___closed__0));
return v___x_152_;
}
else
{
lean_object* v_head_153_; lean_object* v_tail_154_; uint32_t v___x_155_; lean_object* v___x_156_; lean_object* v___x_157_; uint8_t v___x_158_; 
v_head_153_ = lean_ctor_get(v_x_151_, 0);
v_tail_154_ = lean_ctor_get(v_x_151_, 1);
v___x_155_ = lean_unbox_uint32(v_head_153_);
v___x_156_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value(v___x_155_);
v___x_157_ = lean_unsigned_to_nat(0u);
v___x_158_ = lean_nat_dec_eq(v___x_156_, v___x_157_);
if (v___x_158_ == 0)
{
if (lean_obj_tag(v_tail_154_) == 0)
{
lean_object* v___x_159_; 
v___x_159_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_159_, 0, v___x_156_);
return v___x_159_;
}
else
{
lean_object* v_head_160_; uint32_t v___x_161_; lean_object* v___x_162_; uint8_t v___x_163_; 
v_head_160_ = lean_ctor_get(v_tail_154_, 0);
v___x_161_ = lean_unbox_uint32(v_head_160_);
v___x_162_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_value(v___x_161_);
v___x_163_ = lean_nat_dec_lt(v___x_156_, v___x_162_);
lean_dec(v___x_162_);
if (v___x_163_ == 0)
{
lean_object* v___x_164_; 
v___x_164_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(v_tail_154_);
if (lean_obj_tag(v___x_164_) == 0)
{
lean_dec(v___x_156_);
return v___x_164_;
}
else
{
lean_object* v_val_165_; lean_object* v___x_167_; uint8_t v_isShared_168_; uint8_t v_isSharedCheck_173_; 
v_val_165_ = lean_ctor_get(v___x_164_, 0);
v_isSharedCheck_173_ = !lean_is_exclusive(v___x_164_);
if (v_isSharedCheck_173_ == 0)
{
v___x_167_ = v___x_164_;
v_isShared_168_ = v_isSharedCheck_173_;
goto v_resetjp_166_;
}
else
{
lean_inc(v_val_165_);
lean_dec(v___x_164_);
v___x_167_ = lean_box(0);
v_isShared_168_ = v_isSharedCheck_173_;
goto v_resetjp_166_;
}
v_resetjp_166_:
{
lean_object* v___x_169_; lean_object* v___x_171_; 
v___x_169_ = lean_nat_add(v_val_165_, v___x_156_);
lean_dec(v___x_156_);
lean_dec(v_val_165_);
if (v_isShared_168_ == 0)
{
lean_ctor_set(v___x_167_, 0, v___x_169_);
v___x_171_ = v___x_167_;
goto v_reusejp_170_;
}
else
{
lean_object* v_reuseFailAlloc_172_; 
v_reuseFailAlloc_172_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_172_, 0, v___x_169_);
v___x_171_ = v_reuseFailAlloc_172_;
goto v_reusejp_170_;
}
v_reusejp_170_:
{
return v___x_171_;
}
}
}
}
else
{
lean_object* v___x_174_; 
v___x_174_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(v_tail_154_);
if (lean_obj_tag(v___x_174_) == 0)
{
lean_dec(v___x_156_);
return v___x_174_;
}
else
{
lean_object* v_val_175_; lean_object* v___x_177_; uint8_t v_isShared_178_; uint8_t v_isSharedCheck_183_; 
v_val_175_ = lean_ctor_get(v___x_174_, 0);
v_isSharedCheck_183_ = !lean_is_exclusive(v___x_174_);
if (v_isSharedCheck_183_ == 0)
{
v___x_177_ = v___x_174_;
v_isShared_178_ = v_isSharedCheck_183_;
goto v_resetjp_176_;
}
else
{
lean_inc(v_val_175_);
lean_dec(v___x_174_);
v___x_177_ = lean_box(0);
v_isShared_178_ = v_isSharedCheck_183_;
goto v_resetjp_176_;
}
v_resetjp_176_:
{
lean_object* v___x_179_; lean_object* v___x_181_; 
v___x_179_ = lean_nat_sub(v_val_175_, v___x_156_);
lean_dec(v___x_156_);
lean_dec(v_val_175_);
if (v_isShared_178_ == 0)
{
lean_ctor_set(v___x_177_, 0, v___x_179_);
v___x_181_ = v___x_177_;
goto v_reusejp_180_;
}
else
{
lean_object* v_reuseFailAlloc_182_; 
v_reuseFailAlloc_182_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_182_, 0, v___x_179_);
v___x_181_ = v_reuseFailAlloc_182_;
goto v_reusejp_180_;
}
v_reusejp_180_:
{
return v___x_181_;
}
}
}
}
}
}
else
{
lean_object* v___x_184_; 
lean_dec(v___x_156_);
v___x_184_ = lean_box(0);
return v___x_184_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux___boxed(lean_object* v_x_185_){
_start:
{
lean_object* v_res_186_; 
v_res_186_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(v_x_185_);
lean_dec(v_x_185_);
return v_res_186_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman_fromRoman(lean_object* v_s_187_){
_start:
{
lean_object* v___x_188_; lean_object* v___x_189_; uint8_t v___x_190_; 
v___x_188_ = lean_string_utf8_byte_size(v_s_187_);
v___x_189_ = lean_unsigned_to_nat(0u);
v___x_190_ = lean_nat_dec_eq(v___x_188_, v___x_189_);
if (v___x_190_ == 0)
{
lean_object* v___x_191_; lean_object* v___x_192_; 
v___x_191_ = lean_string_data(v_s_187_);
v___x_192_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_roman_numerals_roman_0__LeanPythonEmbed_roman_numerals_roman_fromRomanAux(v___x_191_);
lean_dec(v___x_191_);
return v___x_192_;
}
else
{
lean_object* v___x_193_; 
lean_dec_ref(v_s_187_);
v___x_193_ = lean_box(0);
return v___x_193_;
}
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_roman_numerals_roman(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
lean_initialize_runtime_module();
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
