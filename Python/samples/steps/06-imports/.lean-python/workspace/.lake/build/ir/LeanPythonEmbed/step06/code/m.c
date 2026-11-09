// Lean compiler output
// Module: LeanPythonEmbed.step06.code.m
// Imports: public import Init public meta import Init public import Std.Data.HashMap public import Std.Data.HashSet
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
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
lean_object* lean_array_fswap(lean_object*, lean_object*, lean_object*);
lean_object* lean_array_fget_borrowed(lean_object*, lean_object*);
uint8_t lean_string_dec_lt(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
uint8_t lean_usize_dec_eq(size_t, size_t);
size_t lean_usize_sub(size_t, size_t);
lean_object* lean_array_uget_borrowed(lean_object*, size_t);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* lean_array_get_size(lean_object*);
lean_object* lean_nat_mul(lean_object*, lean_object*);
lean_object* lean_mk_array(lean_object*, lean_object*);
lean_object* lean_array_propagate_mark(lean_object*, lean_object*);
lean_object* lean_array_fget(lean_object*, lean_object*);
lean_object* lean_array_fset(lean_object*, lean_object*, lean_object*);
uint64_t lean_string_hash(lean_object*);
uint64_t lean_uint64_shift_right(uint64_t, uint64_t);
uint64_t lean_uint64_xor(uint64_t, uint64_t);
size_t lean_uint64_to_usize(uint64_t);
size_t lean_usize_of_nat(lean_object*);
size_t lean_usize_land(size_t, size_t);
lean_object* lean_array_uset(lean_object*, size_t, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
lean_object* lean_nat_shiftr(lean_object*, lean_object*);
lean_object* l_List_appendTR___redArg(lean_object*, lean_object*);
lean_object* lean_nat_div(lean_object*, lean_object*);
uint64_t lean_uint64_of_nat(lean_object*);
lean_object* lean_array_to_list(lean_object*);
lean_object* lean_array_mk(lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* l_List_zipIdxTR___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3___redArg(lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5(lean_object*, size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_once_cell_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0;
static lean_once_cell_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_dedup_spec__2(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4(lean_object*, size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_once_cell_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0;
static lean_once_cell_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg(lean_object* v_a_1_, lean_object* v_fallback_2_, lean_object* v_x_3_){
_start:
{
if (lean_obj_tag(v_x_3_) == 0)
{
lean_inc(v_fallback_2_);
return v_fallback_2_;
}
else
{
lean_object* v_key_4_; lean_object* v_value_5_; lean_object* v_tail_6_; uint8_t v___x_7_; 
v_key_4_ = lean_ctor_get(v_x_3_, 0);
v_value_5_ = lean_ctor_get(v_x_3_, 1);
v_tail_6_ = lean_ctor_get(v_x_3_, 2);
v___x_7_ = lean_string_dec_eq(v_key_4_, v_a_1_);
if (v___x_7_ == 0)
{
v_x_3_ = v_tail_6_;
goto _start;
}
else
{
lean_inc(v_value_5_);
return v_value_5_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg___boxed(lean_object* v_a_9_, lean_object* v_fallback_10_, lean_object* v_x_11_){
_start:
{
lean_object* v_res_12_; 
v_res_12_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg(v_a_9_, v_fallback_10_, v_x_11_);
lean_dec(v_x_11_);
lean_dec(v_fallback_10_);
lean_dec_ref(v_a_9_);
return v_res_12_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg(lean_object* v_m_13_, lean_object* v_a_14_, lean_object* v_fallback_15_){
_start:
{
lean_object* v_buckets_16_; lean_object* v___x_17_; uint64_t v___x_18_; uint64_t v___x_19_; uint64_t v___x_20_; uint64_t v_fold_21_; uint64_t v___x_22_; uint64_t v___x_23_; uint64_t v___x_24_; size_t v___x_25_; size_t v___x_26_; size_t v___x_27_; size_t v___x_28_; size_t v___x_29_; lean_object* v___x_30_; lean_object* v___x_31_; 
v_buckets_16_ = lean_ctor_get(v_m_13_, 1);
v___x_17_ = lean_array_get_size(v_buckets_16_);
v___x_18_ = lean_string_hash(v_a_14_);
v___x_19_ = 32ULL;
v___x_20_ = lean_uint64_shift_right(v___x_18_, v___x_19_);
v_fold_21_ = lean_uint64_xor(v___x_18_, v___x_20_);
v___x_22_ = 16ULL;
v___x_23_ = lean_uint64_shift_right(v_fold_21_, v___x_22_);
v___x_24_ = lean_uint64_xor(v_fold_21_, v___x_23_);
v___x_25_ = lean_uint64_to_usize(v___x_24_);
v___x_26_ = lean_usize_of_nat(v___x_17_);
v___x_27_ = ((size_t)1ULL);
v___x_28_ = lean_usize_sub(v___x_26_, v___x_27_);
v___x_29_ = lean_usize_land(v___x_25_, v___x_28_);
v___x_30_ = lean_array_uget_borrowed(v_buckets_16_, v___x_29_);
v___x_31_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg(v_a_14_, v_fallback_15_, v___x_30_);
return v___x_31_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg___boxed(lean_object* v_m_32_, lean_object* v_a_33_, lean_object* v_fallback_34_){
_start:
{
lean_object* v_res_35_; 
v_res_35_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg(v_m_32_, v_a_33_, v_fallback_34_);
lean_dec(v_fallback_34_);
lean_dec_ref(v_a_33_);
lean_dec_ref(v_m_32_);
return v_res_35_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4___redArg(lean_object* v_a_36_, lean_object* v_b_37_, lean_object* v_x_38_){
_start:
{
if (lean_obj_tag(v_x_38_) == 0)
{
lean_dec(v_b_37_);
lean_dec_ref(v_a_36_);
return v_x_38_;
}
else
{
lean_object* v_key_39_; lean_object* v_value_40_; lean_object* v_tail_41_; lean_object* v___x_43_; uint8_t v_isShared_44_; uint8_t v_isSharedCheck_53_; 
v_key_39_ = lean_ctor_get(v_x_38_, 0);
v_value_40_ = lean_ctor_get(v_x_38_, 1);
v_tail_41_ = lean_ctor_get(v_x_38_, 2);
v_isSharedCheck_53_ = !lean_is_exclusive(v_x_38_);
if (v_isSharedCheck_53_ == 0)
{
v___x_43_ = v_x_38_;
v_isShared_44_ = v_isSharedCheck_53_;
goto v_resetjp_42_;
}
else
{
lean_inc(v_tail_41_);
lean_inc(v_value_40_);
lean_inc(v_key_39_);
lean_dec(v_x_38_);
v___x_43_ = lean_box(0);
v_isShared_44_ = v_isSharedCheck_53_;
goto v_resetjp_42_;
}
v_resetjp_42_:
{
uint8_t v___x_45_; 
v___x_45_ = lean_string_dec_eq(v_key_39_, v_a_36_);
if (v___x_45_ == 0)
{
lean_object* v___x_46_; lean_object* v___x_48_; 
v___x_46_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4___redArg(v_a_36_, v_b_37_, v_tail_41_);
if (v_isShared_44_ == 0)
{
lean_ctor_set(v___x_43_, 2, v___x_46_);
v___x_48_ = v___x_43_;
goto v_reusejp_47_;
}
else
{
lean_object* v_reuseFailAlloc_49_; 
v_reuseFailAlloc_49_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v_reuseFailAlloc_49_, 0, v_key_39_);
lean_ctor_set(v_reuseFailAlloc_49_, 1, v_value_40_);
lean_ctor_set(v_reuseFailAlloc_49_, 2, v___x_46_);
v___x_48_ = v_reuseFailAlloc_49_;
goto v_reusejp_47_;
}
v_reusejp_47_:
{
return v___x_48_;
}
}
else
{
lean_object* v___x_51_; 
lean_dec(v_value_40_);
lean_dec(v_key_39_);
if (v_isShared_44_ == 0)
{
lean_ctor_set(v___x_43_, 1, v_b_37_);
lean_ctor_set(v___x_43_, 0, v_a_36_);
v___x_51_ = v___x_43_;
goto v_reusejp_50_;
}
else
{
lean_object* v_reuseFailAlloc_52_; 
v_reuseFailAlloc_52_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v_reuseFailAlloc_52_, 0, v_a_36_);
lean_ctor_set(v_reuseFailAlloc_52_, 1, v_b_37_);
lean_ctor_set(v_reuseFailAlloc_52_, 2, v_tail_41_);
v___x_51_ = v_reuseFailAlloc_52_;
goto v_reusejp_50_;
}
v_reusejp_50_:
{
return v___x_51_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9___redArg(lean_object* v_x_54_, lean_object* v_x_55_){
_start:
{
if (lean_obj_tag(v_x_55_) == 0)
{
return v_x_54_;
}
else
{
lean_object* v_key_56_; lean_object* v_value_57_; lean_object* v_tail_58_; lean_object* v___x_60_; uint8_t v_isShared_61_; uint8_t v_isSharedCheck_81_; 
v_key_56_ = lean_ctor_get(v_x_55_, 0);
v_value_57_ = lean_ctor_get(v_x_55_, 1);
v_tail_58_ = lean_ctor_get(v_x_55_, 2);
v_isSharedCheck_81_ = !lean_is_exclusive(v_x_55_);
if (v_isSharedCheck_81_ == 0)
{
v___x_60_ = v_x_55_;
v_isShared_61_ = v_isSharedCheck_81_;
goto v_resetjp_59_;
}
else
{
lean_inc(v_tail_58_);
lean_inc(v_value_57_);
lean_inc(v_key_56_);
lean_dec(v_x_55_);
v___x_60_ = lean_box(0);
v_isShared_61_ = v_isSharedCheck_81_;
goto v_resetjp_59_;
}
v_resetjp_59_:
{
lean_object* v___x_62_; uint64_t v___x_63_; uint64_t v___x_64_; uint64_t v___x_65_; uint64_t v_fold_66_; uint64_t v___x_67_; uint64_t v___x_68_; uint64_t v___x_69_; size_t v___x_70_; size_t v___x_71_; size_t v___x_72_; size_t v___x_73_; size_t v___x_74_; lean_object* v___x_75_; lean_object* v___x_77_; 
v___x_62_ = lean_array_get_size(v_x_54_);
v___x_63_ = lean_string_hash(v_key_56_);
v___x_64_ = 32ULL;
v___x_65_ = lean_uint64_shift_right(v___x_63_, v___x_64_);
v_fold_66_ = lean_uint64_xor(v___x_63_, v___x_65_);
v___x_67_ = 16ULL;
v___x_68_ = lean_uint64_shift_right(v_fold_66_, v___x_67_);
v___x_69_ = lean_uint64_xor(v_fold_66_, v___x_68_);
v___x_70_ = lean_uint64_to_usize(v___x_69_);
v___x_71_ = lean_usize_of_nat(v___x_62_);
v___x_72_ = ((size_t)1ULL);
v___x_73_ = lean_usize_sub(v___x_71_, v___x_72_);
v___x_74_ = lean_usize_land(v___x_70_, v___x_73_);
v___x_75_ = lean_array_uget_borrowed(v_x_54_, v___x_74_);
lean_inc(v___x_75_);
if (v_isShared_61_ == 0)
{
lean_ctor_set(v___x_60_, 2, v___x_75_);
v___x_77_ = v___x_60_;
goto v_reusejp_76_;
}
else
{
lean_object* v_reuseFailAlloc_80_; 
v_reuseFailAlloc_80_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v_reuseFailAlloc_80_, 0, v_key_56_);
lean_ctor_set(v_reuseFailAlloc_80_, 1, v_value_57_);
lean_ctor_set(v_reuseFailAlloc_80_, 2, v___x_75_);
v___x_77_ = v_reuseFailAlloc_80_;
goto v_reusejp_76_;
}
v_reusejp_76_:
{
lean_object* v___x_78_; 
v___x_78_ = lean_array_uset(v_x_54_, v___x_74_, v___x_77_);
v_x_54_ = v___x_78_;
v_x_55_ = v_tail_58_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4___redArg(lean_object* v_i_82_, lean_object* v_source_83_, lean_object* v_target_84_){
_start:
{
lean_object* v___x_85_; uint8_t v___x_86_; 
v___x_85_ = lean_array_get_size(v_source_83_);
v___x_86_ = lean_nat_dec_lt(v_i_82_, v___x_85_);
if (v___x_86_ == 0)
{
lean_dec_ref(v_source_83_);
lean_dec(v_i_82_);
return v_target_84_;
}
else
{
lean_object* v_es_87_; lean_object* v___x_88_; lean_object* v_source_89_; lean_object* v_target_90_; lean_object* v___x_91_; lean_object* v___x_92_; 
v_es_87_ = lean_array_fget(v_source_83_, v_i_82_);
v___x_88_ = lean_box(0);
v_source_89_ = lean_array_fset(v_source_83_, v_i_82_, v___x_88_);
v_target_90_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9___redArg(v_target_84_, v_es_87_);
v___x_91_ = lean_unsigned_to_nat(1u);
v___x_92_ = lean_nat_add(v_i_82_, v___x_91_);
lean_dec(v_i_82_);
v_i_82_ = v___x_92_;
v_source_83_ = v_source_89_;
v_target_84_ = v_target_90_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3___redArg(lean_object* v_data_94_){
_start:
{
lean_object* v___x_95_; lean_object* v___x_96_; lean_object* v_nbuckets_97_; lean_object* v___x_98_; lean_object* v___x_99_; lean_object* v___x_100_; lean_object* v___x_101_; lean_object* v___x_102_; 
v___x_95_ = lean_array_get_size(v_data_94_);
v___x_96_ = lean_unsigned_to_nat(2u);
v_nbuckets_97_ = lean_nat_mul(v___x_95_, v___x_96_);
v___x_98_ = lean_unsigned_to_nat(0u);
v___x_99_ = lean_box(0);
v___x_100_ = lean_mk_array(v_nbuckets_97_, v___x_99_);
v___x_101_ = lean_array_propagate_mark(v_data_94_, v___x_100_);
v___x_102_ = lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4___redArg(v___x_98_, v_data_94_, v___x_101_);
return v___x_102_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg(lean_object* v_a_103_, lean_object* v_x_104_){
_start:
{
if (lean_obj_tag(v_x_104_) == 0)
{
uint8_t v___x_105_; 
v___x_105_ = 0;
return v___x_105_;
}
else
{
lean_object* v_key_106_; lean_object* v_tail_107_; uint8_t v___x_108_; 
v_key_106_ = lean_ctor_get(v_x_104_, 0);
v_tail_107_ = lean_ctor_get(v_x_104_, 2);
v___x_108_ = lean_string_dec_eq(v_key_106_, v_a_103_);
if (v___x_108_ == 0)
{
v_x_104_ = v_tail_107_;
goto _start;
}
else
{
return v___x_108_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg___boxed(lean_object* v_a_110_, lean_object* v_x_111_){
_start:
{
uint8_t v_res_112_; lean_object* v_r_113_; 
v_res_112_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg(v_a_110_, v_x_111_);
lean_dec(v_x_111_);
lean_dec_ref(v_a_110_);
v_r_113_ = lean_box(v_res_112_);
return v_r_113_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1___redArg(lean_object* v_m_114_, lean_object* v_a_115_, lean_object* v_b_116_){
_start:
{
lean_object* v_size_117_; lean_object* v_buckets_118_; lean_object* v___x_120_; uint8_t v_isShared_121_; uint8_t v_isSharedCheck_161_; 
v_size_117_ = lean_ctor_get(v_m_114_, 0);
v_buckets_118_ = lean_ctor_get(v_m_114_, 1);
v_isSharedCheck_161_ = !lean_is_exclusive(v_m_114_);
if (v_isSharedCheck_161_ == 0)
{
v___x_120_ = v_m_114_;
v_isShared_121_ = v_isSharedCheck_161_;
goto v_resetjp_119_;
}
else
{
lean_inc(v_buckets_118_);
lean_inc(v_size_117_);
lean_dec(v_m_114_);
v___x_120_ = lean_box(0);
v_isShared_121_ = v_isSharedCheck_161_;
goto v_resetjp_119_;
}
v_resetjp_119_:
{
lean_object* v___x_122_; uint64_t v___x_123_; uint64_t v___x_124_; uint64_t v___x_125_; uint64_t v_fold_126_; uint64_t v___x_127_; uint64_t v___x_128_; uint64_t v___x_129_; size_t v___x_130_; size_t v___x_131_; size_t v___x_132_; size_t v___x_133_; size_t v___x_134_; lean_object* v_bkt_135_; uint8_t v___x_136_; 
v___x_122_ = lean_array_get_size(v_buckets_118_);
v___x_123_ = lean_string_hash(v_a_115_);
v___x_124_ = 32ULL;
v___x_125_ = lean_uint64_shift_right(v___x_123_, v___x_124_);
v_fold_126_ = lean_uint64_xor(v___x_123_, v___x_125_);
v___x_127_ = 16ULL;
v___x_128_ = lean_uint64_shift_right(v_fold_126_, v___x_127_);
v___x_129_ = lean_uint64_xor(v_fold_126_, v___x_128_);
v___x_130_ = lean_uint64_to_usize(v___x_129_);
v___x_131_ = lean_usize_of_nat(v___x_122_);
v___x_132_ = ((size_t)1ULL);
v___x_133_ = lean_usize_sub(v___x_131_, v___x_132_);
v___x_134_ = lean_usize_land(v___x_130_, v___x_133_);
v_bkt_135_ = lean_array_uget_borrowed(v_buckets_118_, v___x_134_);
v___x_136_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg(v_a_115_, v_bkt_135_);
if (v___x_136_ == 0)
{
lean_object* v___x_137_; lean_object* v_size_x27_138_; lean_object* v___x_139_; lean_object* v_buckets_x27_140_; lean_object* v___x_141_; lean_object* v___x_142_; lean_object* v___x_143_; lean_object* v___x_144_; lean_object* v___x_145_; uint8_t v___x_146_; 
v___x_137_ = lean_unsigned_to_nat(1u);
v_size_x27_138_ = lean_nat_add(v_size_117_, v___x_137_);
lean_dec(v_size_117_);
lean_inc(v_bkt_135_);
v___x_139_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v___x_139_, 0, v_a_115_);
lean_ctor_set(v___x_139_, 1, v_b_116_);
lean_ctor_set(v___x_139_, 2, v_bkt_135_);
v_buckets_x27_140_ = lean_array_uset(v_buckets_118_, v___x_134_, v___x_139_);
v___x_141_ = lean_unsigned_to_nat(4u);
v___x_142_ = lean_nat_mul(v_size_x27_138_, v___x_141_);
v___x_143_ = lean_unsigned_to_nat(3u);
v___x_144_ = lean_nat_div(v___x_142_, v___x_143_);
lean_dec(v___x_142_);
v___x_145_ = lean_array_get_size(v_buckets_x27_140_);
v___x_146_ = lean_nat_dec_le(v___x_144_, v___x_145_);
lean_dec(v___x_144_);
if (v___x_146_ == 0)
{
lean_object* v_val_147_; lean_object* v___x_149_; 
v_val_147_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3___redArg(v_buckets_x27_140_);
if (v_isShared_121_ == 0)
{
lean_ctor_set(v___x_120_, 1, v_val_147_);
lean_ctor_set(v___x_120_, 0, v_size_x27_138_);
v___x_149_ = v___x_120_;
goto v_reusejp_148_;
}
else
{
lean_object* v_reuseFailAlloc_150_; 
v_reuseFailAlloc_150_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_150_, 0, v_size_x27_138_);
lean_ctor_set(v_reuseFailAlloc_150_, 1, v_val_147_);
v___x_149_ = v_reuseFailAlloc_150_;
goto v_reusejp_148_;
}
v_reusejp_148_:
{
return v___x_149_;
}
}
else
{
lean_object* v___x_152_; 
if (v_isShared_121_ == 0)
{
lean_ctor_set(v___x_120_, 1, v_buckets_x27_140_);
lean_ctor_set(v___x_120_, 0, v_size_x27_138_);
v___x_152_ = v___x_120_;
goto v_reusejp_151_;
}
else
{
lean_object* v_reuseFailAlloc_153_; 
v_reuseFailAlloc_153_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_153_, 0, v_size_x27_138_);
lean_ctor_set(v_reuseFailAlloc_153_, 1, v_buckets_x27_140_);
v___x_152_ = v_reuseFailAlloc_153_;
goto v_reusejp_151_;
}
v_reusejp_151_:
{
return v___x_152_;
}
}
}
else
{
lean_object* v___x_154_; lean_object* v_buckets_x27_155_; lean_object* v___x_156_; lean_object* v___x_157_; lean_object* v___x_159_; 
lean_inc(v_bkt_135_);
v___x_154_ = lean_box(0);
v_buckets_x27_155_ = lean_array_uset(v_buckets_118_, v___x_134_, v___x_154_);
v___x_156_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4___redArg(v_a_115_, v_b_116_, v_bkt_135_);
v___x_157_ = lean_array_uset(v_buckets_x27_155_, v___x_134_, v___x_156_);
if (v_isShared_121_ == 0)
{
lean_ctor_set(v___x_120_, 1, v___x_157_);
v___x_159_ = v___x_120_;
goto v_reusejp_158_;
}
else
{
lean_object* v_reuseFailAlloc_160_; 
v_reuseFailAlloc_160_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_160_, 0, v_size_117_);
lean_ctor_set(v_reuseFailAlloc_160_, 1, v___x_157_);
v___x_159_ = v_reuseFailAlloc_160_;
goto v_reusejp_158_;
}
v_reusejp_158_:
{
return v___x_159_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__3(lean_object* v_x_162_, lean_object* v_x_163_){
_start:
{
if (lean_obj_tag(v_x_163_) == 0)
{
return v_x_162_;
}
else
{
lean_object* v_head_164_; lean_object* v_tail_165_; lean_object* v___x_167_; uint8_t v_isShared_168_; uint8_t v_isSharedCheck_179_; 
v_head_164_ = lean_ctor_get(v_x_163_, 0);
v_tail_165_ = lean_ctor_get(v_x_163_, 1);
v_isSharedCheck_179_ = !lean_is_exclusive(v_x_163_);
if (v_isSharedCheck_179_ == 0)
{
v___x_167_ = v_x_163_;
v_isShared_168_ = v_isSharedCheck_179_;
goto v_resetjp_166_;
}
else
{
lean_inc(v_tail_165_);
lean_inc(v_head_164_);
lean_dec(v_x_163_);
v___x_167_ = lean_box(0);
v_isShared_168_ = v_isSharedCheck_179_;
goto v_resetjp_166_;
}
v_resetjp_166_:
{
lean_object* v_fst_169_; lean_object* v_snd_170_; lean_object* v___x_171_; lean_object* v___x_172_; lean_object* v___x_174_; 
v_fst_169_ = lean_ctor_get(v_head_164_, 0);
lean_inc(v_fst_169_);
v_snd_170_ = lean_ctor_get(v_head_164_, 1);
lean_inc(v_snd_170_);
lean_dec(v_head_164_);
v___x_171_ = lean_box(0);
v___x_172_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg(v_x_162_, v_fst_169_, v___x_171_);
if (v_isShared_168_ == 0)
{
lean_ctor_set(v___x_167_, 1, v___x_171_);
lean_ctor_set(v___x_167_, 0, v_snd_170_);
v___x_174_ = v___x_167_;
goto v_reusejp_173_;
}
else
{
lean_object* v_reuseFailAlloc_178_; 
v_reuseFailAlloc_178_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_178_, 0, v_snd_170_);
lean_ctor_set(v_reuseFailAlloc_178_, 1, v___x_171_);
v___x_174_ = v_reuseFailAlloc_178_;
goto v_reusejp_173_;
}
v_reusejp_173_:
{
lean_object* v___x_175_; lean_object* v___x_176_; 
v___x_175_ = l_List_appendTR___redArg(v___x_172_, v___x_174_);
v___x_176_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1___redArg(v_x_162_, v_fst_169_, v___x_175_);
v_x_162_ = v___x_176_;
v_x_163_ = v_tail_165_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg(lean_object* v_hi_180_, lean_object* v_pivot_181_, lean_object* v_as_182_, lean_object* v_i_183_, lean_object* v_k_184_){
_start:
{
uint8_t v___x_185_; 
v___x_185_ = lean_nat_dec_lt(v_k_184_, v_hi_180_);
if (v___x_185_ == 0)
{
lean_object* v___x_186_; lean_object* v___x_187_; 
lean_dec(v_k_184_);
v___x_186_ = lean_array_fswap(v_as_182_, v_i_183_, v_hi_180_);
v___x_187_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_187_, 0, v_i_183_);
lean_ctor_set(v___x_187_, 1, v___x_186_);
return v___x_187_;
}
else
{
lean_object* v___x_188_; lean_object* v_fst_189_; lean_object* v_fst_190_; uint8_t v___x_191_; 
v___x_188_ = lean_array_fget_borrowed(v_as_182_, v_k_184_);
v_fst_189_ = lean_ctor_get(v___x_188_, 0);
v_fst_190_ = lean_ctor_get(v_pivot_181_, 0);
v___x_191_ = lean_string_dec_lt(v_fst_189_, v_fst_190_);
if (v___x_191_ == 0)
{
lean_object* v___x_192_; lean_object* v___x_193_; 
v___x_192_ = lean_unsigned_to_nat(1u);
v___x_193_ = lean_nat_add(v_k_184_, v___x_192_);
lean_dec(v_k_184_);
v_k_184_ = v___x_193_;
goto _start;
}
else
{
lean_object* v___x_195_; lean_object* v___x_196_; lean_object* v___x_197_; lean_object* v___x_198_; 
v___x_195_ = lean_array_fswap(v_as_182_, v_i_183_, v_k_184_);
v___x_196_ = lean_unsigned_to_nat(1u);
v___x_197_ = lean_nat_add(v_i_183_, v___x_196_);
lean_dec(v_i_183_);
v___x_198_ = lean_nat_add(v_k_184_, v___x_196_);
lean_dec(v_k_184_);
v_as_182_ = v___x_195_;
v_i_183_ = v___x_197_;
v_k_184_ = v___x_198_;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg___boxed(lean_object* v_hi_200_, lean_object* v_pivot_201_, lean_object* v_as_202_, lean_object* v_i_203_, lean_object* v_k_204_){
_start:
{
lean_object* v_res_205_; 
v_res_205_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg(v_hi_200_, v_pivot_201_, v_as_202_, v_i_203_, v_k_204_);
lean_dec_ref(v_pivot_201_);
lean_dec(v_hi_200_);
return v_res_205_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(lean_object* v_a_206_, lean_object* v_b_207_){
_start:
{
lean_object* v_fst_208_; lean_object* v_fst_209_; uint8_t v___x_210_; 
v_fst_208_ = lean_ctor_get(v_a_206_, 0);
v_fst_209_ = lean_ctor_get(v_b_207_, 0);
v___x_210_ = lean_string_dec_lt(v_fst_208_, v_fst_209_);
return v___x_210_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0___boxed(lean_object* v_a_211_, lean_object* v_b_212_){
_start:
{
uint8_t v_res_213_; lean_object* v_r_214_; 
v_res_213_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(v_a_211_, v_b_212_);
lean_dec_ref(v_b_212_);
lean_dec_ref(v_a_211_);
v_r_214_ = lean_box(v_res_213_);
return v_r_214_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(lean_object* v_n_215_, lean_object* v_as_216_, lean_object* v_lo_217_, lean_object* v_hi_218_){
_start:
{
lean_object* v___y_220_; uint8_t v___x_230_; 
v___x_230_ = lean_nat_dec_lt(v_lo_217_, v_hi_218_);
if (v___x_230_ == 0)
{
lean_dec(v_lo_217_);
return v_as_216_;
}
else
{
lean_object* v___x_231_; lean_object* v___x_232_; lean_object* v_mid_233_; lean_object* v___y_235_; lean_object* v___y_241_; lean_object* v___x_246_; lean_object* v___x_247_; uint8_t v___x_248_; 
v___x_231_ = lean_nat_add(v_lo_217_, v_hi_218_);
v___x_232_ = lean_unsigned_to_nat(1u);
v_mid_233_ = lean_nat_shiftr(v___x_231_, v___x_232_);
lean_dec(v___x_231_);
v___x_246_ = lean_array_fget_borrowed(v_as_216_, v_mid_233_);
v___x_247_ = lean_array_fget_borrowed(v_as_216_, v_lo_217_);
v___x_248_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(v___x_246_, v___x_247_);
if (v___x_248_ == 0)
{
v___y_241_ = v_as_216_;
goto v___jp_240_;
}
else
{
lean_object* v___x_249_; 
v___x_249_ = lean_array_fswap(v_as_216_, v_lo_217_, v_mid_233_);
v___y_241_ = v___x_249_;
goto v___jp_240_;
}
v___jp_234_:
{
lean_object* v___x_236_; lean_object* v___x_237_; uint8_t v___x_238_; 
v___x_236_ = lean_array_fget_borrowed(v___y_235_, v_mid_233_);
v___x_237_ = lean_array_fget_borrowed(v___y_235_, v_hi_218_);
v___x_238_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(v___x_236_, v___x_237_);
if (v___x_238_ == 0)
{
lean_dec(v_mid_233_);
v___y_220_ = v___y_235_;
goto v___jp_219_;
}
else
{
lean_object* v___x_239_; 
v___x_239_ = lean_array_fswap(v___y_235_, v_mid_233_, v_hi_218_);
lean_dec(v_mid_233_);
v___y_220_ = v___x_239_;
goto v___jp_219_;
}
}
v___jp_240_:
{
lean_object* v___x_242_; lean_object* v___x_243_; uint8_t v___x_244_; 
v___x_242_ = lean_array_fget_borrowed(v___y_241_, v_hi_218_);
v___x_243_ = lean_array_fget_borrowed(v___y_241_, v_lo_217_);
v___x_244_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___lam__0(v___x_242_, v___x_243_);
if (v___x_244_ == 0)
{
v___y_235_ = v___y_241_;
goto v___jp_234_;
}
else
{
lean_object* v___x_245_; 
v___x_245_ = lean_array_fswap(v___y_241_, v_lo_217_, v_hi_218_);
v___y_235_ = v___x_245_;
goto v___jp_234_;
}
}
}
v___jp_219_:
{
lean_object* v_pivot_221_; lean_object* v___x_222_; lean_object* v_fst_223_; lean_object* v_snd_224_; uint8_t v___x_225_; 
v_pivot_221_ = lean_array_fget(v___y_220_, v_hi_218_);
lean_inc_n(v_lo_217_, 2);
v___x_222_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg(v_hi_218_, v_pivot_221_, v___y_220_, v_lo_217_, v_lo_217_);
lean_dec(v_pivot_221_);
v_fst_223_ = lean_ctor_get(v___x_222_, 0);
lean_inc(v_fst_223_);
v_snd_224_ = lean_ctor_get(v___x_222_, 1);
lean_inc(v_snd_224_);
lean_dec_ref(v___x_222_);
v___x_225_ = lean_nat_dec_le(v_hi_218_, v_fst_223_);
if (v___x_225_ == 0)
{
lean_object* v___x_226_; lean_object* v___x_227_; lean_object* v___x_228_; 
v___x_226_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(v_n_215_, v_snd_224_, v_lo_217_, v_fst_223_);
v___x_227_ = lean_unsigned_to_nat(1u);
v___x_228_ = lean_nat_add(v_fst_223_, v___x_227_);
lean_dec(v_fst_223_);
v_as_216_ = v___x_226_;
v_lo_217_ = v___x_228_;
goto _start;
}
else
{
lean_dec(v_fst_223_);
lean_dec(v_lo_217_);
return v_snd_224_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg___boxed(lean_object* v_n_250_, lean_object* v_as_251_, lean_object* v_lo_252_, lean_object* v_hi_253_){
_start:
{
lean_object* v_res_254_; 
v_res_254_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(v_n_250_, v_as_251_, v_lo_252_, v_hi_253_);
lean_dec(v_hi_253_);
lean_dec(v_n_250_);
return v_res_254_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4(lean_object* v_x_255_, lean_object* v_x_256_){
_start:
{
if (lean_obj_tag(v_x_256_) == 0)
{
lean_inc(v_x_255_);
return v_x_255_;
}
else
{
lean_object* v_key_257_; lean_object* v_value_258_; lean_object* v_tail_259_; lean_object* v___x_260_; lean_object* v___x_261_; lean_object* v___x_262_; 
v_key_257_ = lean_ctor_get(v_x_256_, 0);
v_value_258_ = lean_ctor_get(v_x_256_, 1);
v_tail_259_ = lean_ctor_get(v_x_256_, 2);
v___x_260_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4(v_x_255_, v_tail_259_);
lean_inc(v_value_258_);
lean_inc(v_key_257_);
v___x_261_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_261_, 0, v_key_257_);
lean_ctor_set(v___x_261_, 1, v_value_258_);
v___x_262_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_262_, 0, v___x_261_);
lean_ctor_set(v___x_262_, 1, v___x_260_);
return v___x_262_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4___boxed(lean_object* v_x_263_, lean_object* v_x_264_){
_start:
{
lean_object* v_res_265_; 
v_res_265_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4(v_x_263_, v_x_264_);
lean_dec(v_x_264_);
lean_dec(v_x_263_);
return v_res_265_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5(lean_object* v_as_266_, size_t v_i_267_, size_t v_stop_268_, lean_object* v_b_269_){
_start:
{
uint8_t v___x_270_; 
v___x_270_ = lean_usize_dec_eq(v_i_267_, v_stop_268_);
if (v___x_270_ == 0)
{
size_t v___x_271_; size_t v___x_272_; lean_object* v___x_273_; lean_object* v___x_274_; 
v___x_271_ = ((size_t)1ULL);
v___x_272_ = lean_usize_sub(v_i_267_, v___x_271_);
v___x_273_ = lean_array_uget_borrowed(v_as_266_, v___x_272_);
v___x_274_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__4(v_b_269_, v___x_273_);
lean_dec(v_b_269_);
v_i_267_ = v___x_272_;
v_b_269_ = v___x_274_;
goto _start;
}
else
{
return v_b_269_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5___boxed(lean_object* v_as_276_, lean_object* v_i_277_, lean_object* v_stop_278_, lean_object* v_b_279_){
_start:
{
size_t v_i_boxed_280_; size_t v_stop_boxed_281_; lean_object* v_res_282_; 
v_i_boxed_280_ = lean_unbox_usize(v_i_277_);
lean_dec(v_i_277_);
v_stop_boxed_281_ = lean_unbox_usize(v_stop_278_);
lean_dec(v_stop_278_);
v_res_282_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5(v_as_276_, v_i_boxed_280_, v_stop_boxed_281_, v_b_279_);
lean_dec_ref(v_as_276_);
return v_res_282_;
}
}
static lean_object* _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0(void){
_start:
{
lean_object* v___x_283_; lean_object* v___x_284_; lean_object* v___x_285_; 
v___x_283_ = lean_box(0);
v___x_284_ = lean_unsigned_to_nat(16u);
v___x_285_ = lean_mk_array(v___x_284_, v___x_283_);
return v___x_285_;
}
}
static lean_object* _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1(void){
_start:
{
lean_object* v___x_286_; lean_object* v___x_287_; lean_object* v___x_288_; 
v___x_286_ = lean_obj_once(&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0, &lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0_once, _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__0);
v___x_287_ = lean_unsigned_to_nat(0u);
v___x_288_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_288_, 0, v___x_287_);
lean_ctor_set(v___x_288_, 1, v___x_286_);
return v___x_288_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex(lean_object* v_ws_289_){
_start:
{
lean_object* v___y_291_; lean_object* v___y_292_; lean_object* v___y_293_; lean_object* v___y_294_; lean_object* v___y_298_; lean_object* v___y_299_; lean_object* v___y_300_; lean_object* v___y_301_; lean_object* v___x_303_; lean_object* v___y_305_; lean_object* v___x_313_; lean_object* v___x_314_; lean_object* v_idx_315_; lean_object* v_buckets_316_; lean_object* v___x_317_; lean_object* v___x_318_; uint8_t v___x_319_; 
v___x_303_ = lean_unsigned_to_nat(0u);
v___x_313_ = lean_obj_once(&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1, &lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1_once, _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_wordIndex___closed__1);
v___x_314_ = l_List_zipIdxTR___redArg(v_ws_289_, v___x_303_);
v_idx_315_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__3(v___x_313_, v___x_314_);
v_buckets_316_ = lean_ctor_get(v_idx_315_, 1);
lean_inc_ref(v_buckets_316_);
lean_dec_ref(v_idx_315_);
v___x_317_ = lean_box(0);
v___x_318_ = lean_array_get_size(v_buckets_316_);
v___x_319_ = lean_nat_dec_lt(v___x_303_, v___x_318_);
if (v___x_319_ == 0)
{
lean_dec_ref(v_buckets_316_);
v___y_305_ = v___x_317_;
goto v___jp_304_;
}
else
{
size_t v___x_320_; size_t v___x_321_; lean_object* v___x_322_; 
v___x_320_ = lean_usize_of_nat(v___x_318_);
v___x_321_ = ((size_t)0ULL);
v___x_322_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__5(v_buckets_316_, v___x_320_, v___x_321_, v___x_317_);
lean_dec_ref(v_buckets_316_);
v___y_305_ = v___x_322_;
goto v___jp_304_;
}
v___jp_290_:
{
lean_object* v___x_295_; lean_object* v___x_296_; 
v___x_295_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(v___y_293_, v___y_292_, v___y_291_, v___y_294_);
lean_dec(v___y_294_);
lean_dec(v___y_293_);
v___x_296_ = lean_array_to_list(v___x_295_);
return v___x_296_;
}
v___jp_297_:
{
uint8_t v___x_302_; 
v___x_302_ = lean_nat_dec_le(v___y_301_, v___y_298_);
if (v___x_302_ == 0)
{
lean_dec(v___y_298_);
lean_inc(v___y_301_);
v___y_291_ = v___y_301_;
v___y_292_ = v___y_299_;
v___y_293_ = v___y_300_;
v___y_294_ = v___y_301_;
goto v___jp_290_;
}
else
{
v___y_291_ = v___y_301_;
v___y_292_ = v___y_299_;
v___y_293_ = v___y_300_;
v___y_294_ = v___y_298_;
goto v___jp_290_;
}
}
v___jp_304_:
{
lean_object* v___x_306_; lean_object* v___x_307_; uint8_t v___x_308_; 
v___x_306_ = lean_array_mk(v___y_305_);
v___x_307_ = lean_array_get_size(v___x_306_);
v___x_308_ = lean_nat_dec_eq(v___x_307_, v___x_303_);
if (v___x_308_ == 0)
{
lean_object* v___x_309_; lean_object* v___x_310_; uint8_t v___x_311_; 
v___x_309_ = lean_unsigned_to_nat(1u);
v___x_310_ = lean_nat_sub(v___x_307_, v___x_309_);
v___x_311_ = lean_nat_dec_le(v___x_303_, v___x_310_);
if (v___x_311_ == 0)
{
lean_inc(v___x_310_);
v___y_298_ = v___x_310_;
v___y_299_ = v___x_306_;
v___y_300_ = v___x_307_;
v___y_301_ = v___x_310_;
goto v___jp_297_;
}
else
{
v___y_298_ = v___x_310_;
v___y_299_ = v___x_306_;
v___y_300_ = v___x_307_;
v___y_301_ = v___x_303_;
goto v___jp_297_;
}
}
else
{
lean_object* v___x_312_; 
v___x_312_ = lean_array_to_list(v___x_306_);
return v___x_312_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0(lean_object* v_00_u03b2_323_, lean_object* v_m_324_, lean_object* v_a_325_, lean_object* v_fallback_326_){
_start:
{
lean_object* v___x_327_; 
v___x_327_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___redArg(v_m_324_, v_a_325_, v_fallback_326_);
return v___x_327_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0___boxed(lean_object* v_00_u03b2_328_, lean_object* v_m_329_, lean_object* v_a_330_, lean_object* v_fallback_331_){
_start:
{
lean_object* v_res_332_; 
v_res_332_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0(v_00_u03b2_328_, v_m_329_, v_a_330_, v_fallback_331_);
lean_dec(v_fallback_331_);
lean_dec_ref(v_a_330_);
lean_dec_ref(v_m_329_);
return v_res_332_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1(lean_object* v_00_u03b2_333_, lean_object* v_m_334_, lean_object* v_a_335_, lean_object* v_b_336_){
_start:
{
lean_object* v___x_337_; 
v___x_337_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1___redArg(v_m_334_, v_a_335_, v_b_336_);
return v___x_337_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2(lean_object* v_n_338_, lean_object* v_as_339_, lean_object* v_lo_340_, lean_object* v_hi_341_, lean_object* v_w_342_, lean_object* v_hlo_343_, lean_object* v_hhi_344_){
_start:
{
lean_object* v___x_345_; 
v___x_345_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___redArg(v_n_338_, v_as_339_, v_lo_340_, v_hi_341_);
return v___x_345_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2___boxed(lean_object* v_n_346_, lean_object* v_as_347_, lean_object* v_lo_348_, lean_object* v_hi_349_, lean_object* v_w_350_, lean_object* v_hlo_351_, lean_object* v_hhi_352_){
_start:
{
lean_object* v_res_353_; 
v_res_353_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2(v_n_346_, v_as_347_, v_lo_348_, v_hi_349_, v_w_350_, v_hlo_351_, v_hhi_352_);
lean_dec(v_hi_349_);
lean_dec(v_n_346_);
return v_res_353_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0(lean_object* v_00_u03b2_354_, lean_object* v_a_355_, lean_object* v_fallback_356_, lean_object* v_x_357_){
_start:
{
lean_object* v___x_358_; 
v___x_358_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___redArg(v_a_355_, v_fallback_356_, v_x_357_);
return v___x_358_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0___boxed(lean_object* v_00_u03b2_359_, lean_object* v_a_360_, lean_object* v_fallback_361_, lean_object* v_x_362_){
_start:
{
lean_object* v_res_363_; 
v_res_363_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_getD___at___00Std_DHashMap_Internal_Raw_u2080_Const_getD___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__0_spec__0(v_00_u03b2_359_, v_a_360_, v_fallback_361_, v_x_362_);
lean_dec(v_x_362_);
lean_dec(v_fallback_361_);
lean_dec_ref(v_a_360_);
return v_res_363_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2(lean_object* v_00_u03b2_364_, lean_object* v_a_365_, lean_object* v_x_366_){
_start:
{
uint8_t v___x_367_; 
v___x_367_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___redArg(v_a_365_, v_x_366_);
return v___x_367_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2___boxed(lean_object* v_00_u03b2_368_, lean_object* v_a_369_, lean_object* v_x_370_){
_start:
{
uint8_t v_res_371_; lean_object* v_r_372_; 
v_res_371_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__2(v_00_u03b2_368_, v_a_369_, v_x_370_);
lean_dec(v_x_370_);
lean_dec_ref(v_a_369_);
v_r_372_ = lean_box(v_res_371_);
return v_r_372_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3(lean_object* v_00_u03b2_373_, lean_object* v_data_374_){
_start:
{
lean_object* v___x_375_; 
v___x_375_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3___redArg(v_data_374_);
return v___x_375_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4(lean_object* v_00_u03b2_376_, lean_object* v_a_377_, lean_object* v_b_378_, lean_object* v_x_379_){
_start:
{
lean_object* v___x_380_; 
v___x_380_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_replace___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__4___redArg(v_a_377_, v_b_378_, v_x_379_);
return v___x_380_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6(lean_object* v_n_381_, lean_object* v_lo_382_, lean_object* v_hi_383_, lean_object* v_hhi_384_, lean_object* v_pivot_385_, lean_object* v_as_386_, lean_object* v_i_387_, lean_object* v_k_388_, lean_object* v_ilo_389_, lean_object* v_ik_390_, lean_object* v_w_391_){
_start:
{
lean_object* v___x_392_; 
v___x_392_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___redArg(v_hi_383_, v_pivot_385_, v_as_386_, v_i_387_, v_k_388_);
return v___x_392_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6___boxed(lean_object* v_n_393_, lean_object* v_lo_394_, lean_object* v_hi_395_, lean_object* v_hhi_396_, lean_object* v_pivot_397_, lean_object* v_as_398_, lean_object* v_i_399_, lean_object* v_k_400_, lean_object* v_ilo_401_, lean_object* v_ik_402_, lean_object* v_w_403_){
_start:
{
lean_object* v_res_404_; 
v_res_404_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__2_spec__6(v_n_393_, v_lo_394_, v_hi_395_, v_hhi_396_, v_pivot_397_, v_as_398_, v_i_399_, v_k_400_, v_ilo_401_, v_ik_402_, v_w_403_);
lean_dec_ref(v_pivot_397_);
lean_dec(v_hi_395_);
lean_dec(v_lo_394_);
lean_dec(v_n_393_);
return v_res_404_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4(lean_object* v_00_u03b2_405_, lean_object* v_i_406_, lean_object* v_source_407_, lean_object* v_target_408_){
_start:
{
lean_object* v___x_409_; 
v___x_409_ = lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4___redArg(v_i_406_, v_source_407_, v_target_408_);
return v___x_409_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9(lean_object* v_00_u03b2_410_, lean_object* v_x_411_, lean_object* v_x_412_){
_start:
{
lean_object* v___x_413_; 
v___x_413_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insert___at___00LeanPythonEmbed_step06_code_m_wordIndex_spec__1_spec__3_spec__4_spec__9___redArg(v_x_411_, v_x_412_);
return v___x_413_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg(lean_object* v_a_414_, lean_object* v_x_415_){
_start:
{
if (lean_obj_tag(v_x_415_) == 0)
{
uint8_t v___x_416_; 
v___x_416_ = 0;
return v___x_416_;
}
else
{
lean_object* v_key_417_; lean_object* v_tail_418_; uint8_t v___x_419_; 
v_key_417_ = lean_ctor_get(v_x_415_, 0);
v_tail_418_ = lean_ctor_get(v_x_415_, 2);
v___x_419_ = lean_nat_dec_eq(v_key_417_, v_a_414_);
if (v___x_419_ == 0)
{
v_x_415_ = v_tail_418_;
goto _start;
}
else
{
return v___x_419_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg___boxed(lean_object* v_a_421_, lean_object* v_x_422_){
_start:
{
uint8_t v_res_423_; lean_object* v_r_424_; 
v_res_423_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg(v_a_421_, v_x_422_);
lean_dec(v_x_422_);
lean_dec(v_a_421_);
v_r_424_ = lean_box(v_res_423_);
return v_r_424_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8___redArg(lean_object* v_x_425_, lean_object* v_x_426_){
_start:
{
if (lean_obj_tag(v_x_426_) == 0)
{
return v_x_425_;
}
else
{
lean_object* v_key_427_; lean_object* v_value_428_; lean_object* v_tail_429_; lean_object* v___x_431_; uint8_t v_isShared_432_; uint8_t v_isSharedCheck_452_; 
v_key_427_ = lean_ctor_get(v_x_426_, 0);
v_value_428_ = lean_ctor_get(v_x_426_, 1);
v_tail_429_ = lean_ctor_get(v_x_426_, 2);
v_isSharedCheck_452_ = !lean_is_exclusive(v_x_426_);
if (v_isSharedCheck_452_ == 0)
{
v___x_431_ = v_x_426_;
v_isShared_432_ = v_isSharedCheck_452_;
goto v_resetjp_430_;
}
else
{
lean_inc(v_tail_429_);
lean_inc(v_value_428_);
lean_inc(v_key_427_);
lean_dec(v_x_426_);
v___x_431_ = lean_box(0);
v_isShared_432_ = v_isSharedCheck_452_;
goto v_resetjp_430_;
}
v_resetjp_430_:
{
lean_object* v___x_433_; uint64_t v___x_434_; uint64_t v___x_435_; uint64_t v___x_436_; uint64_t v_fold_437_; uint64_t v___x_438_; uint64_t v___x_439_; uint64_t v___x_440_; size_t v___x_441_; size_t v___x_442_; size_t v___x_443_; size_t v___x_444_; size_t v___x_445_; lean_object* v___x_446_; lean_object* v___x_448_; 
v___x_433_ = lean_array_get_size(v_x_425_);
v___x_434_ = lean_uint64_of_nat(v_key_427_);
v___x_435_ = 32ULL;
v___x_436_ = lean_uint64_shift_right(v___x_434_, v___x_435_);
v_fold_437_ = lean_uint64_xor(v___x_434_, v___x_436_);
v___x_438_ = 16ULL;
v___x_439_ = lean_uint64_shift_right(v_fold_437_, v___x_438_);
v___x_440_ = lean_uint64_xor(v_fold_437_, v___x_439_);
v___x_441_ = lean_uint64_to_usize(v___x_440_);
v___x_442_ = lean_usize_of_nat(v___x_433_);
v___x_443_ = ((size_t)1ULL);
v___x_444_ = lean_usize_sub(v___x_442_, v___x_443_);
v___x_445_ = lean_usize_land(v___x_441_, v___x_444_);
v___x_446_ = lean_array_uget_borrowed(v_x_425_, v___x_445_);
lean_inc(v___x_446_);
if (v_isShared_432_ == 0)
{
lean_ctor_set(v___x_431_, 2, v___x_446_);
v___x_448_ = v___x_431_;
goto v_reusejp_447_;
}
else
{
lean_object* v_reuseFailAlloc_451_; 
v_reuseFailAlloc_451_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v_reuseFailAlloc_451_, 0, v_key_427_);
lean_ctor_set(v_reuseFailAlloc_451_, 1, v_value_428_);
lean_ctor_set(v_reuseFailAlloc_451_, 2, v___x_446_);
v___x_448_ = v_reuseFailAlloc_451_;
goto v_reusejp_447_;
}
v_reusejp_447_:
{
lean_object* v___x_449_; 
v___x_449_ = lean_array_uset(v_x_425_, v___x_445_, v___x_448_);
v_x_425_ = v___x_449_;
v_x_426_ = v_tail_429_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4___redArg(lean_object* v_i_453_, lean_object* v_source_454_, lean_object* v_target_455_){
_start:
{
lean_object* v___x_456_; uint8_t v___x_457_; 
v___x_456_ = lean_array_get_size(v_source_454_);
v___x_457_ = lean_nat_dec_lt(v_i_453_, v___x_456_);
if (v___x_457_ == 0)
{
lean_dec_ref(v_source_454_);
lean_dec(v_i_453_);
return v_target_455_;
}
else
{
lean_object* v_es_458_; lean_object* v___x_459_; lean_object* v_source_460_; lean_object* v_target_461_; lean_object* v___x_462_; lean_object* v___x_463_; 
v_es_458_ = lean_array_fget(v_source_454_, v_i_453_);
v___x_459_ = lean_box(0);
v_source_460_ = lean_array_fset(v_source_454_, v_i_453_, v___x_459_);
v_target_461_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8___redArg(v_target_455_, v_es_458_);
v___x_462_ = lean_unsigned_to_nat(1u);
v___x_463_ = lean_nat_add(v_i_453_, v___x_462_);
lean_dec(v_i_453_);
v_i_453_ = v___x_463_;
v_source_454_ = v_source_460_;
v_target_455_ = v_target_461_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3___redArg(lean_object* v_data_465_){
_start:
{
lean_object* v___x_466_; lean_object* v___x_467_; lean_object* v_nbuckets_468_; lean_object* v___x_469_; lean_object* v___x_470_; lean_object* v___x_471_; lean_object* v___x_472_; lean_object* v___x_473_; 
v___x_466_ = lean_array_get_size(v_data_465_);
v___x_467_ = lean_unsigned_to_nat(2u);
v_nbuckets_468_ = lean_nat_mul(v___x_466_, v___x_467_);
v___x_469_ = lean_unsigned_to_nat(0u);
v___x_470_ = lean_box(0);
v___x_471_ = lean_mk_array(v_nbuckets_468_, v___x_470_);
v___x_472_ = lean_array_propagate_mark(v_data_465_, v___x_471_);
v___x_473_ = lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4___redArg(v___x_469_, v_data_465_, v___x_472_);
return v___x_473_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1___redArg(lean_object* v_m_474_, lean_object* v_a_475_, lean_object* v_b_476_){
_start:
{
lean_object* v_size_477_; lean_object* v_buckets_478_; lean_object* v___x_479_; uint64_t v___x_480_; uint64_t v___x_481_; uint64_t v___x_482_; uint64_t v_fold_483_; uint64_t v___x_484_; uint64_t v___x_485_; uint64_t v___x_486_; size_t v___x_487_; size_t v___x_488_; size_t v___x_489_; size_t v___x_490_; size_t v___x_491_; lean_object* v_bkt_492_; uint8_t v___x_493_; 
v_size_477_ = lean_ctor_get(v_m_474_, 0);
v_buckets_478_ = lean_ctor_get(v_m_474_, 1);
v___x_479_ = lean_array_get_size(v_buckets_478_);
v___x_480_ = lean_uint64_of_nat(v_a_475_);
v___x_481_ = 32ULL;
v___x_482_ = lean_uint64_shift_right(v___x_480_, v___x_481_);
v_fold_483_ = lean_uint64_xor(v___x_480_, v___x_482_);
v___x_484_ = 16ULL;
v___x_485_ = lean_uint64_shift_right(v_fold_483_, v___x_484_);
v___x_486_ = lean_uint64_xor(v_fold_483_, v___x_485_);
v___x_487_ = lean_uint64_to_usize(v___x_486_);
v___x_488_ = lean_usize_of_nat(v___x_479_);
v___x_489_ = ((size_t)1ULL);
v___x_490_ = lean_usize_sub(v___x_488_, v___x_489_);
v___x_491_ = lean_usize_land(v___x_487_, v___x_490_);
v_bkt_492_ = lean_array_uget_borrowed(v_buckets_478_, v___x_491_);
v___x_493_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg(v_a_475_, v_bkt_492_);
if (v___x_493_ == 0)
{
lean_object* v___x_495_; uint8_t v_isShared_496_; uint8_t v_isSharedCheck_514_; 
lean_inc_ref(v_buckets_478_);
lean_inc(v_size_477_);
v_isSharedCheck_514_ = !lean_is_exclusive(v_m_474_);
if (v_isSharedCheck_514_ == 0)
{
lean_object* v_unused_515_; lean_object* v_unused_516_; 
v_unused_515_ = lean_ctor_get(v_m_474_, 1);
lean_dec(v_unused_515_);
v_unused_516_ = lean_ctor_get(v_m_474_, 0);
lean_dec(v_unused_516_);
v___x_495_ = v_m_474_;
v_isShared_496_ = v_isSharedCheck_514_;
goto v_resetjp_494_;
}
else
{
lean_dec(v_m_474_);
v___x_495_ = lean_box(0);
v_isShared_496_ = v_isSharedCheck_514_;
goto v_resetjp_494_;
}
v_resetjp_494_:
{
lean_object* v___x_497_; lean_object* v_size_x27_498_; lean_object* v___x_499_; lean_object* v_buckets_x27_500_; lean_object* v___x_501_; lean_object* v___x_502_; lean_object* v___x_503_; lean_object* v___x_504_; lean_object* v___x_505_; uint8_t v___x_506_; 
v___x_497_ = lean_unsigned_to_nat(1u);
v_size_x27_498_ = lean_nat_add(v_size_477_, v___x_497_);
lean_dec(v_size_477_);
lean_inc(v_bkt_492_);
v___x_499_ = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(v___x_499_, 0, v_a_475_);
lean_ctor_set(v___x_499_, 1, v_b_476_);
lean_ctor_set(v___x_499_, 2, v_bkt_492_);
v_buckets_x27_500_ = lean_array_uset(v_buckets_478_, v___x_491_, v___x_499_);
v___x_501_ = lean_unsigned_to_nat(4u);
v___x_502_ = lean_nat_mul(v_size_x27_498_, v___x_501_);
v___x_503_ = lean_unsigned_to_nat(3u);
v___x_504_ = lean_nat_div(v___x_502_, v___x_503_);
lean_dec(v___x_502_);
v___x_505_ = lean_array_get_size(v_buckets_x27_500_);
v___x_506_ = lean_nat_dec_le(v___x_504_, v___x_505_);
lean_dec(v___x_504_);
if (v___x_506_ == 0)
{
lean_object* v_val_507_; lean_object* v___x_509_; 
v_val_507_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3___redArg(v_buckets_x27_500_);
if (v_isShared_496_ == 0)
{
lean_ctor_set(v___x_495_, 1, v_val_507_);
lean_ctor_set(v___x_495_, 0, v_size_x27_498_);
v___x_509_ = v___x_495_;
goto v_reusejp_508_;
}
else
{
lean_object* v_reuseFailAlloc_510_; 
v_reuseFailAlloc_510_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_510_, 0, v_size_x27_498_);
lean_ctor_set(v_reuseFailAlloc_510_, 1, v_val_507_);
v___x_509_ = v_reuseFailAlloc_510_;
goto v_reusejp_508_;
}
v_reusejp_508_:
{
return v___x_509_;
}
}
else
{
lean_object* v___x_512_; 
if (v_isShared_496_ == 0)
{
lean_ctor_set(v___x_495_, 1, v_buckets_x27_500_);
lean_ctor_set(v___x_495_, 0, v_size_x27_498_);
v___x_512_ = v___x_495_;
goto v_reusejp_511_;
}
else
{
lean_object* v_reuseFailAlloc_513_; 
v_reuseFailAlloc_513_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_513_, 0, v_size_x27_498_);
lean_ctor_set(v_reuseFailAlloc_513_, 1, v_buckets_x27_500_);
v___x_512_ = v_reuseFailAlloc_513_;
goto v_reusejp_511_;
}
v_reusejp_511_:
{
return v___x_512_;
}
}
}
}
else
{
lean_dec(v_b_476_);
lean_dec(v_a_475_);
return v_m_474_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_dedup_spec__2(lean_object* v_x_517_, lean_object* v_x_518_){
_start:
{
if (lean_obj_tag(v_x_518_) == 0)
{
return v_x_517_;
}
else
{
lean_object* v_head_519_; lean_object* v_tail_520_; lean_object* v___x_521_; lean_object* v___x_522_; 
v_head_519_ = lean_ctor_get(v_x_518_, 0);
lean_inc(v_head_519_);
v_tail_520_ = lean_ctor_get(v_x_518_, 1);
lean_inc(v_tail_520_);
lean_dec_ref_known(v_x_518_, 2);
v___x_521_ = lean_box(0);
v___x_522_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1___redArg(v_x_517_, v_head_519_, v___x_521_);
v_x_517_ = v___x_522_;
v_x_518_ = v_tail_520_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg(lean_object* v_hi_524_, lean_object* v_pivot_525_, lean_object* v_as_526_, lean_object* v_i_527_, lean_object* v_k_528_){
_start:
{
uint8_t v___x_529_; 
v___x_529_ = lean_nat_dec_lt(v_k_528_, v_hi_524_);
if (v___x_529_ == 0)
{
lean_object* v___x_530_; lean_object* v___x_531_; 
lean_dec(v_k_528_);
v___x_530_ = lean_array_fswap(v_as_526_, v_i_527_, v_hi_524_);
v___x_531_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_531_, 0, v_i_527_);
lean_ctor_set(v___x_531_, 1, v___x_530_);
return v___x_531_;
}
else
{
lean_object* v___x_532_; uint8_t v___x_533_; 
v___x_532_ = lean_array_fget_borrowed(v_as_526_, v_k_528_);
v___x_533_ = lean_nat_dec_lt(v___x_532_, v_pivot_525_);
if (v___x_533_ == 0)
{
lean_object* v___x_534_; lean_object* v___x_535_; 
v___x_534_ = lean_unsigned_to_nat(1u);
v___x_535_ = lean_nat_add(v_k_528_, v___x_534_);
lean_dec(v_k_528_);
v_k_528_ = v___x_535_;
goto _start;
}
else
{
lean_object* v___x_537_; lean_object* v___x_538_; lean_object* v___x_539_; lean_object* v___x_540_; 
v___x_537_ = lean_array_fswap(v_as_526_, v_i_527_, v_k_528_);
v___x_538_ = lean_unsigned_to_nat(1u);
v___x_539_ = lean_nat_add(v_i_527_, v___x_538_);
lean_dec(v_i_527_);
v___x_540_ = lean_nat_add(v_k_528_, v___x_538_);
lean_dec(v_k_528_);
v_as_526_ = v___x_537_;
v_i_527_ = v___x_539_;
v_k_528_ = v___x_540_;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg___boxed(lean_object* v_hi_542_, lean_object* v_pivot_543_, lean_object* v_as_544_, lean_object* v_i_545_, lean_object* v_k_546_){
_start:
{
lean_object* v_res_547_; 
v_res_547_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg(v_hi_542_, v_pivot_543_, v_as_544_, v_i_545_, v_k_546_);
lean_dec(v_pivot_543_);
lean_dec(v_hi_542_);
return v_res_547_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(lean_object* v_n_548_, lean_object* v_as_549_, lean_object* v_lo_550_, lean_object* v_hi_551_){
_start:
{
lean_object* v___y_553_; uint8_t v___x_563_; 
v___x_563_ = lean_nat_dec_lt(v_lo_550_, v_hi_551_);
if (v___x_563_ == 0)
{
lean_dec(v_lo_550_);
return v_as_549_;
}
else
{
lean_object* v___x_564_; lean_object* v___x_565_; lean_object* v_mid_566_; lean_object* v___y_568_; lean_object* v___y_574_; lean_object* v___x_579_; lean_object* v___x_580_; uint8_t v___x_581_; 
v___x_564_ = lean_nat_add(v_lo_550_, v_hi_551_);
v___x_565_ = lean_unsigned_to_nat(1u);
v_mid_566_ = lean_nat_shiftr(v___x_564_, v___x_565_);
lean_dec(v___x_564_);
v___x_579_ = lean_array_fget_borrowed(v_as_549_, v_mid_566_);
v___x_580_ = lean_array_fget_borrowed(v_as_549_, v_lo_550_);
v___x_581_ = lean_nat_dec_lt(v___x_579_, v___x_580_);
if (v___x_581_ == 0)
{
v___y_574_ = v_as_549_;
goto v___jp_573_;
}
else
{
lean_object* v___x_582_; 
v___x_582_ = lean_array_fswap(v_as_549_, v_lo_550_, v_mid_566_);
v___y_574_ = v___x_582_;
goto v___jp_573_;
}
v___jp_567_:
{
lean_object* v___x_569_; lean_object* v___x_570_; uint8_t v___x_571_; 
v___x_569_ = lean_array_fget_borrowed(v___y_568_, v_mid_566_);
v___x_570_ = lean_array_fget_borrowed(v___y_568_, v_hi_551_);
v___x_571_ = lean_nat_dec_lt(v___x_569_, v___x_570_);
if (v___x_571_ == 0)
{
lean_dec(v_mid_566_);
v___y_553_ = v___y_568_;
goto v___jp_552_;
}
else
{
lean_object* v___x_572_; 
v___x_572_ = lean_array_fswap(v___y_568_, v_mid_566_, v_hi_551_);
lean_dec(v_mid_566_);
v___y_553_ = v___x_572_;
goto v___jp_552_;
}
}
v___jp_573_:
{
lean_object* v___x_575_; lean_object* v___x_576_; uint8_t v___x_577_; 
v___x_575_ = lean_array_fget_borrowed(v___y_574_, v_hi_551_);
v___x_576_ = lean_array_fget_borrowed(v___y_574_, v_lo_550_);
v___x_577_ = lean_nat_dec_lt(v___x_575_, v___x_576_);
if (v___x_577_ == 0)
{
v___y_568_ = v___y_574_;
goto v___jp_567_;
}
else
{
lean_object* v___x_578_; 
v___x_578_ = lean_array_fswap(v___y_574_, v_lo_550_, v_hi_551_);
v___y_568_ = v___x_578_;
goto v___jp_567_;
}
}
}
v___jp_552_:
{
lean_object* v_pivot_554_; lean_object* v___x_555_; lean_object* v_fst_556_; lean_object* v_snd_557_; uint8_t v___x_558_; 
v_pivot_554_ = lean_array_fget(v___y_553_, v_hi_551_);
lean_inc_n(v_lo_550_, 2);
v___x_555_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg(v_hi_551_, v_pivot_554_, v___y_553_, v_lo_550_, v_lo_550_);
lean_dec(v_pivot_554_);
v_fst_556_ = lean_ctor_get(v___x_555_, 0);
lean_inc(v_fst_556_);
v_snd_557_ = lean_ctor_get(v___x_555_, 1);
lean_inc(v_snd_557_);
lean_dec_ref(v___x_555_);
v___x_558_ = lean_nat_dec_le(v_hi_551_, v_fst_556_);
if (v___x_558_ == 0)
{
lean_object* v___x_559_; lean_object* v___x_560_; lean_object* v___x_561_; 
v___x_559_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(v_n_548_, v_snd_557_, v_lo_550_, v_fst_556_);
v___x_560_ = lean_unsigned_to_nat(1u);
v___x_561_ = lean_nat_add(v_fst_556_, v___x_560_);
lean_dec(v_fst_556_);
v_as_549_ = v___x_559_;
v_lo_550_ = v___x_561_;
goto _start;
}
else
{
lean_dec(v_fst_556_);
lean_dec(v_lo_550_);
return v_snd_557_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg___boxed(lean_object* v_n_583_, lean_object* v_as_584_, lean_object* v_lo_585_, lean_object* v_hi_586_){
_start:
{
lean_object* v_res_587_; 
v_res_587_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(v_n_583_, v_as_584_, v_lo_585_, v_hi_586_);
lean_dec(v_hi_586_);
lean_dec(v_n_583_);
return v_res_587_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3(lean_object* v_x_588_, lean_object* v_x_589_){
_start:
{
if (lean_obj_tag(v_x_589_) == 0)
{
lean_inc(v_x_588_);
return v_x_588_;
}
else
{
lean_object* v_key_590_; lean_object* v_tail_591_; lean_object* v___x_592_; lean_object* v___x_593_; 
v_key_590_ = lean_ctor_get(v_x_589_, 0);
v_tail_591_ = lean_ctor_get(v_x_589_, 2);
v___x_592_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3(v_x_588_, v_tail_591_);
lean_inc(v_key_590_);
v___x_593_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_593_, 0, v_key_590_);
lean_ctor_set(v___x_593_, 1, v___x_592_);
return v___x_593_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3___boxed(lean_object* v_x_594_, lean_object* v_x_595_){
_start:
{
lean_object* v_res_596_; 
v_res_596_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3(v_x_594_, v_x_595_);
lean_dec(v_x_595_);
lean_dec(v_x_594_);
return v_res_596_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4(lean_object* v_as_597_, size_t v_i_598_, size_t v_stop_599_, lean_object* v_b_600_){
_start:
{
uint8_t v___x_601_; 
v___x_601_ = lean_usize_dec_eq(v_i_598_, v_stop_599_);
if (v___x_601_ == 0)
{
size_t v___x_602_; size_t v___x_603_; lean_object* v___x_604_; lean_object* v___x_605_; 
v___x_602_ = ((size_t)1ULL);
v___x_603_ = lean_usize_sub(v_i_598_, v___x_602_);
v___x_604_ = lean_array_uget_borrowed(v_as_597_, v___x_603_);
v___x_605_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldrM___at___00LeanPythonEmbed_step06_code_m_dedup_spec__3(v_b_600_, v___x_604_);
lean_dec(v_b_600_);
v_i_598_ = v___x_603_;
v_b_600_ = v___x_605_;
goto _start;
}
else
{
return v_b_600_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4___boxed(lean_object* v_as_607_, lean_object* v_i_608_, lean_object* v_stop_609_, lean_object* v_b_610_){
_start:
{
size_t v_i_boxed_611_; size_t v_stop_boxed_612_; lean_object* v_res_613_; 
v_i_boxed_611_ = lean_unbox_usize(v_i_608_);
lean_dec(v_i_608_);
v_stop_boxed_612_ = lean_unbox_usize(v_stop_609_);
lean_dec(v_stop_609_);
v_res_613_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4(v_as_607_, v_i_boxed_611_, v_stop_boxed_612_, v_b_610_);
lean_dec_ref(v_as_607_);
return v_res_613_;
}
}
static lean_object* _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0(void){
_start:
{
lean_object* v___x_614_; lean_object* v___x_615_; lean_object* v___x_616_; 
v___x_614_ = lean_box(0);
v___x_615_ = lean_unsigned_to_nat(16u);
v___x_616_ = lean_mk_array(v___x_615_, v___x_614_);
return v___x_616_;
}
}
static lean_object* _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1(void){
_start:
{
lean_object* v___x_617_; lean_object* v___x_618_; lean_object* v___x_619_; 
v___x_617_ = lean_obj_once(&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0, &lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0_once, _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__0);
v___x_618_ = lean_unsigned_to_nat(0u);
v___x_619_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_619_, 0, v___x_618_);
lean_ctor_set(v___x_619_, 1, v___x_617_);
return v___x_619_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup(lean_object* v_xs_620_){
_start:
{
lean_object* v___y_622_; lean_object* v___y_623_; lean_object* v___y_624_; lean_object* v___y_625_; lean_object* v___y_629_; lean_object* v___y_630_; lean_object* v___y_631_; lean_object* v___y_632_; lean_object* v___y_635_; lean_object* v___x_644_; lean_object* v___x_645_; lean_object* v_s_646_; lean_object* v_buckets_647_; lean_object* v___x_648_; lean_object* v___x_649_; uint8_t v___x_650_; 
v___x_644_ = lean_unsigned_to_nat(0u);
v___x_645_ = lean_obj_once(&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1, &lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1_once, _init_lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m_dedup___closed__1);
v_s_646_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step06_code_m_dedup_spec__2(v___x_645_, v_xs_620_);
v_buckets_647_ = lean_ctor_get(v_s_646_, 1);
lean_inc_ref(v_buckets_647_);
lean_dec_ref(v_s_646_);
v___x_648_ = lean_box(0);
v___x_649_ = lean_array_get_size(v_buckets_647_);
v___x_650_ = lean_nat_dec_lt(v___x_644_, v___x_649_);
if (v___x_650_ == 0)
{
lean_dec_ref(v_buckets_647_);
v___y_635_ = v___x_648_;
goto v___jp_634_;
}
else
{
size_t v___x_651_; size_t v___x_652_; lean_object* v___x_653_; 
v___x_651_ = lean_usize_of_nat(v___x_649_);
v___x_652_ = ((size_t)0ULL);
v___x_653_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00LeanPythonEmbed_step06_code_m_dedup_spec__4(v_buckets_647_, v___x_651_, v___x_652_, v___x_648_);
lean_dec_ref(v_buckets_647_);
v___y_635_ = v___x_653_;
goto v___jp_634_;
}
v___jp_621_:
{
lean_object* v___x_626_; lean_object* v___x_627_; 
v___x_626_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(v___y_622_, v___y_624_, v___y_623_, v___y_625_);
lean_dec(v___y_625_);
lean_dec(v___y_622_);
v___x_627_ = lean_array_to_list(v___x_626_);
return v___x_627_;
}
v___jp_628_:
{
uint8_t v___x_633_; 
v___x_633_ = lean_nat_dec_le(v___y_632_, v___y_630_);
if (v___x_633_ == 0)
{
lean_dec(v___y_630_);
lean_inc(v___y_632_);
v___y_622_ = v___y_629_;
v___y_623_ = v___y_632_;
v___y_624_ = v___y_631_;
v___y_625_ = v___y_632_;
goto v___jp_621_;
}
else
{
v___y_622_ = v___y_629_;
v___y_623_ = v___y_632_;
v___y_624_ = v___y_631_;
v___y_625_ = v___y_630_;
goto v___jp_621_;
}
}
v___jp_634_:
{
lean_object* v___x_636_; lean_object* v___x_637_; lean_object* v___x_638_; uint8_t v___x_639_; 
v___x_636_ = lean_array_mk(v___y_635_);
v___x_637_ = lean_array_get_size(v___x_636_);
v___x_638_ = lean_unsigned_to_nat(0u);
v___x_639_ = lean_nat_dec_eq(v___x_637_, v___x_638_);
if (v___x_639_ == 0)
{
lean_object* v___x_640_; lean_object* v___x_641_; uint8_t v___x_642_; 
v___x_640_ = lean_unsigned_to_nat(1u);
v___x_641_ = lean_nat_sub(v___x_637_, v___x_640_);
v___x_642_ = lean_nat_dec_le(v___x_638_, v___x_641_);
if (v___x_642_ == 0)
{
lean_inc(v___x_641_);
v___y_629_ = v___x_637_;
v___y_630_ = v___x_641_;
v___y_631_ = v___x_636_;
v___y_632_ = v___x_641_;
goto v___jp_628_;
}
else
{
v___y_629_ = v___x_637_;
v___y_630_ = v___x_641_;
v___y_631_ = v___x_636_;
v___y_632_ = v___x_638_;
goto v___jp_628_;
}
}
else
{
lean_object* v___x_643_; 
v___x_643_ = lean_array_to_list(v___x_636_);
return v___x_643_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0(lean_object* v_n_654_, lean_object* v_as_655_, lean_object* v_lo_656_, lean_object* v_hi_657_, lean_object* v_w_658_, lean_object* v_hlo_659_, lean_object* v_hhi_660_){
_start:
{
lean_object* v___x_661_; 
v___x_661_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___redArg(v_n_654_, v_as_655_, v_lo_656_, v_hi_657_);
return v___x_661_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0___boxed(lean_object* v_n_662_, lean_object* v_as_663_, lean_object* v_lo_664_, lean_object* v_hi_665_, lean_object* v_w_666_, lean_object* v_hlo_667_, lean_object* v_hhi_668_){
_start:
{
lean_object* v_res_669_; 
v_res_669_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0(v_n_662_, v_as_663_, v_lo_664_, v_hi_665_, v_w_666_, v_hlo_667_, v_hhi_668_);
lean_dec(v_hi_665_);
lean_dec(v_n_662_);
return v_res_669_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1(lean_object* v_00_u03b2_670_, lean_object* v_m_671_, lean_object* v_a_672_, lean_object* v_b_673_){
_start:
{
lean_object* v___x_674_; 
v___x_674_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1___redArg(v_m_671_, v_a_672_, v_b_673_);
return v___x_674_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0(lean_object* v_n_675_, lean_object* v_lo_676_, lean_object* v_hi_677_, lean_object* v_hhi_678_, lean_object* v_pivot_679_, lean_object* v_as_680_, lean_object* v_i_681_, lean_object* v_k_682_, lean_object* v_ilo_683_, lean_object* v_ik_684_, lean_object* v_w_685_){
_start:
{
lean_object* v___x_686_; 
v___x_686_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___redArg(v_hi_677_, v_pivot_679_, v_as_680_, v_i_681_, v_k_682_);
return v___x_686_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0___boxed(lean_object* v_n_687_, lean_object* v_lo_688_, lean_object* v_hi_689_, lean_object* v_hhi_690_, lean_object* v_pivot_691_, lean_object* v_as_692_, lean_object* v_i_693_, lean_object* v_k_694_, lean_object* v_ilo_695_, lean_object* v_ik_696_, lean_object* v_w_697_){
_start:
{
lean_object* v_res_698_; 
v_res_698_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_QSort_Basic_0__Array_qpartition_loop___at___00__private_Init_Data_Array_QSort_Basic_0__Array_qsort_sort___at___00LeanPythonEmbed_step06_code_m_dedup_spec__0_spec__0(v_n_687_, v_lo_688_, v_hi_689_, v_hhi_690_, v_pivot_691_, v_as_692_, v_i_693_, v_k_694_, v_ilo_695_, v_ik_696_, v_w_697_);
lean_dec(v_pivot_691_);
lean_dec(v_hi_689_);
lean_dec(v_lo_688_);
lean_dec(v_n_687_);
return v_res_698_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2(lean_object* v_00_u03b2_699_, lean_object* v_a_700_, lean_object* v_x_701_){
_start:
{
uint8_t v___x_702_; 
v___x_702_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___redArg(v_a_700_, v_x_701_);
return v___x_702_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2___boxed(lean_object* v_00_u03b2_703_, lean_object* v_a_704_, lean_object* v_x_705_){
_start:
{
uint8_t v_res_706_; lean_object* v_r_707_; 
v_res_706_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__2(v_00_u03b2_703_, v_a_704_, v_x_705_);
lean_dec(v_x_705_);
lean_dec(v_a_704_);
v_r_707_ = lean_box(v_res_706_);
return v_r_707_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3(lean_object* v_00_u03b2_708_, lean_object* v_data_709_){
_start:
{
lean_object* v___x_710_; 
v___x_710_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3___redArg(v_data_709_);
return v___x_710_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4(lean_object* v_00_u03b2_711_, lean_object* v_i_712_, lean_object* v_source_713_, lean_object* v_target_714_){
_start:
{
lean_object* v___x_715_; 
v___x_715_ = lp_lean_x2dpython_x2dworkspace___private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4___redArg(v_i_712_, v_source_713_, v_target_714_);
return v___x_715_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8(lean_object* v_00_u03b2_716_, lean_object* v_x_717_, lean_object* v_x_718_){
_start:
{
lean_object* v___x_719_; 
v___x_719_ = lp_lean_x2dpython_x2dworkspace_Std_DHashMap_Internal_AssocList_foldlM___at___00__private_Std_Data_DHashMap_Internal_Defs_0__Std_DHashMap_Internal_Raw_u2080_expand_go___at___00Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00LeanPythonEmbed_step06_code_m_dedup_spec__1_spec__3_spec__4_spec__8___redArg(v_x_717_, v_x_718_);
return v___x_719_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Std_Data_HashMap(uint8_t builtin);
lean_object* initialize_Std_Data_HashSet(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step06_code_m(uint8_t builtin) {
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
res = initialize_Std_Data_HashMap(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Std_Data_HashSet(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
