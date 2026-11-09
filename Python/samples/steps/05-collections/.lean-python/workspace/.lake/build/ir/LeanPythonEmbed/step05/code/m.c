// Lean compiler output
// Module: LeanPythonEmbed.step05.code.m
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
size_t lean_array_size(lean_object*);
uint8_t lean_usize_dec_lt(size_t, size_t);
lean_object* lean_array_uget(lean_object*, size_t);
lean_object* lean_array_uset(lean_object*, size_t, lean_object*);
lean_object* l_Int_pow(lean_object*, lean_object*);
size_t lean_usize_add(size_t, size_t);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
lean_object* lean_array_get_size(lean_object*);
lean_object* lean_array_fget(lean_object*, lean_object*);
lean_object* lean_array_fset(lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* l_List_reverse___redArg(lean_object*);
lean_object* lean_nat_mod(lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_mk_array(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_filterTR_loop___at___00LeanPythonEmbed_step05_code_m_evens_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_evens(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0(size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_squares(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_lookup(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_lookup___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_histogram(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_histogram___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_filterTR_loop___at___00LeanPythonEmbed_step05_code_m_evens_spec__0(lean_object* v_a_1_, lean_object* v_a_2_){
_start:
{
if (lean_obj_tag(v_a_1_) == 0)
{
lean_object* v___x_3_; 
v___x_3_ = l_List_reverse___redArg(v_a_2_);
return v___x_3_;
}
else
{
lean_object* v_head_4_; lean_object* v_tail_5_; lean_object* v___x_7_; uint8_t v_isShared_8_; uint8_t v_isSharedCheck_18_; 
v_head_4_ = lean_ctor_get(v_a_1_, 0);
v_tail_5_ = lean_ctor_get(v_a_1_, 1);
v_isSharedCheck_18_ = !lean_is_exclusive(v_a_1_);
if (v_isSharedCheck_18_ == 0)
{
v___x_7_ = v_a_1_;
v_isShared_8_ = v_isSharedCheck_18_;
goto v_resetjp_6_;
}
else
{
lean_inc(v_tail_5_);
lean_inc(v_head_4_);
lean_dec(v_a_1_);
v___x_7_ = lean_box(0);
v_isShared_8_ = v_isSharedCheck_18_;
goto v_resetjp_6_;
}
v_resetjp_6_:
{
lean_object* v___x_9_; lean_object* v___x_10_; lean_object* v___x_11_; uint8_t v___x_12_; 
v___x_9_ = lean_unsigned_to_nat(2u);
v___x_10_ = lean_nat_mod(v_head_4_, v___x_9_);
v___x_11_ = lean_unsigned_to_nat(0u);
v___x_12_ = lean_nat_dec_eq(v___x_10_, v___x_11_);
lean_dec(v___x_10_);
if (v___x_12_ == 0)
{
lean_del_object(v___x_7_);
lean_dec(v_head_4_);
v_a_1_ = v_tail_5_;
goto _start;
}
else
{
lean_object* v___x_15_; 
if (v_isShared_8_ == 0)
{
lean_ctor_set(v___x_7_, 1, v_a_2_);
v___x_15_ = v___x_7_;
goto v_reusejp_14_;
}
else
{
lean_object* v_reuseFailAlloc_17_; 
v_reuseFailAlloc_17_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_17_, 0, v_head_4_);
lean_ctor_set(v_reuseFailAlloc_17_, 1, v_a_2_);
v___x_15_ = v_reuseFailAlloc_17_;
goto v_reusejp_14_;
}
v_reusejp_14_:
{
v_a_1_ = v_tail_5_;
v_a_2_ = v___x_15_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_evens(lean_object* v_xs_19_){
_start:
{
lean_object* v___x_20_; lean_object* v___x_21_; 
v___x_20_ = lean_box(0);
v___x_21_ = lp_lean_x2dpython_x2dworkspace_List_filterTR_loop___at___00LeanPythonEmbed_step05_code_m_evens_spec__0(v_xs_19_, v___x_20_);
return v___x_21_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0(size_t v_sz_22_, size_t v_i_23_, lean_object* v_bs_24_){
_start:
{
uint8_t v___x_25_; 
v___x_25_ = lean_usize_dec_lt(v_i_23_, v_sz_22_);
if (v___x_25_ == 0)
{
return v_bs_24_;
}
else
{
lean_object* v_v_26_; lean_object* v___x_27_; lean_object* v_bs_x27_28_; lean_object* v___x_29_; lean_object* v___x_30_; size_t v___x_31_; size_t v___x_32_; lean_object* v___x_33_; 
v_v_26_ = lean_array_uget(v_bs_24_, v_i_23_);
v___x_27_ = lean_unsigned_to_nat(0u);
v_bs_x27_28_ = lean_array_uset(v_bs_24_, v_i_23_, v___x_27_);
v___x_29_ = lean_unsigned_to_nat(2u);
v___x_30_ = l_Int_pow(v_v_26_, v___x_29_);
lean_dec(v_v_26_);
v___x_31_ = ((size_t)1ULL);
v___x_32_ = lean_usize_add(v_i_23_, v___x_31_);
v___x_33_ = lean_array_uset(v_bs_x27_28_, v_i_23_, v___x_30_);
v_i_23_ = v___x_32_;
v_bs_24_ = v___x_33_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0___boxed(lean_object* v_sz_35_, lean_object* v_i_36_, lean_object* v_bs_37_){
_start:
{
size_t v_sz_boxed_38_; size_t v_i_boxed_39_; lean_object* v_res_40_; 
v_sz_boxed_38_ = lean_unbox_usize(v_sz_35_);
lean_dec(v_sz_35_);
v_i_boxed_39_ = lean_unbox_usize(v_i_36_);
lean_dec(v_i_36_);
v_res_40_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0(v_sz_boxed_38_, v_i_boxed_39_, v_bs_37_);
return v_res_40_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_squares(lean_object* v_xs_41_){
_start:
{
size_t v_sz_42_; size_t v___x_43_; lean_object* v___x_44_; 
v_sz_42_ = lean_array_size(v_xs_41_);
v___x_43_ = ((size_t)0ULL);
v___x_44_ = lp_lean_x2dpython_x2dworkspace___private_Init_Data_Array_Basic_0__Array_mapMUnsafe_map___at___00LeanPythonEmbed_step05_code_m_squares_spec__0(v_sz_42_, v___x_43_, v_xs_41_);
return v___x_44_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg(lean_object* v_x_45_, lean_object* v_x_46_){
_start:
{
if (lean_obj_tag(v_x_46_) == 0)
{
lean_object* v___x_47_; 
v___x_47_ = lean_box(0);
return v___x_47_;
}
else
{
lean_object* v_head_48_; lean_object* v_tail_49_; lean_object* v_fst_50_; lean_object* v_snd_51_; uint8_t v___x_52_; 
v_head_48_ = lean_ctor_get(v_x_46_, 0);
v_tail_49_ = lean_ctor_get(v_x_46_, 1);
v_fst_50_ = lean_ctor_get(v_head_48_, 0);
v_snd_51_ = lean_ctor_get(v_head_48_, 1);
v___x_52_ = lean_string_dec_eq(v_x_45_, v_fst_50_);
if (v___x_52_ == 0)
{
v_x_46_ = v_tail_49_;
goto _start;
}
else
{
lean_object* v___x_54_; 
lean_inc(v_snd_51_);
v___x_54_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_54_, 0, v_snd_51_);
return v___x_54_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg___boxed(lean_object* v_x_55_, lean_object* v_x_56_){
_start:
{
lean_object* v_res_57_; 
v_res_57_ = lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg(v_x_55_, v_x_56_);
lean_dec(v_x_56_);
lean_dec_ref(v_x_55_);
return v_res_57_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_lookup(lean_object* v_k_58_, lean_object* v_xs_59_){
_start:
{
lean_object* v___x_60_; 
v___x_60_ = lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg(v_k_58_, v_xs_59_);
return v___x_60_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_lookup___boxed(lean_object* v_k_61_, lean_object* v_xs_62_){
_start:
{
lean_object* v_res_63_; 
v_res_63_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_lookup(v_k_61_, v_xs_62_);
lean_dec(v_xs_62_);
lean_dec_ref(v_k_61_);
return v_res_63_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0(lean_object* v_00_u03b2_64_, lean_object* v_x_65_, lean_object* v_x_66_){
_start:
{
lean_object* v___x_67_; 
v___x_67_ = lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___redArg(v_x_65_, v_x_66_);
return v___x_67_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0___boxed(lean_object* v_00_u03b2_68_, lean_object* v_x_69_, lean_object* v_x_70_){
_start:
{
lean_object* v_res_71_; 
v_res_71_ = lp_lean_x2dpython_x2dworkspace_List_lookup___at___00LeanPythonEmbed_step05_code_m_lookup_spec__0(v_00_u03b2_68_, v_x_69_, v_x_70_);
lean_dec(v_x_70_);
lean_dec_ref(v_x_69_);
return v_res_71_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg(lean_object* v_buckets_72_, lean_object* v_as_x27_73_, lean_object* v_b_74_){
_start:
{
if (lean_obj_tag(v_as_x27_73_) == 0)
{
return v_b_74_;
}
else
{
lean_object* v_head_75_; lean_object* v_tail_76_; uint8_t v___x_77_; 
v_head_75_ = lean_ctor_get(v_as_x27_73_, 0);
v_tail_76_ = lean_ctor_get(v_as_x27_73_, 1);
v___x_77_ = lean_nat_dec_lt(v_head_75_, v_buckets_72_);
if (v___x_77_ == 0)
{
v_as_x27_73_ = v_tail_76_;
goto _start;
}
else
{
lean_object* v___x_79_; uint8_t v___x_80_; 
v___x_79_ = lean_array_get_size(v_b_74_);
v___x_80_ = lean_nat_dec_lt(v_head_75_, v___x_79_);
if (v___x_80_ == 0)
{
v_as_x27_73_ = v_tail_76_;
goto _start;
}
else
{
lean_object* v_v_82_; lean_object* v___x_83_; lean_object* v_xs_x27_84_; lean_object* v___x_85_; lean_object* v___x_86_; lean_object* v___x_87_; 
v_v_82_ = lean_array_fget(v_b_74_, v_head_75_);
v___x_83_ = lean_box(0);
v_xs_x27_84_ = lean_array_fset(v_b_74_, v_head_75_, v___x_83_);
v___x_85_ = lean_unsigned_to_nat(1u);
v___x_86_ = lean_nat_add(v_v_82_, v___x_85_);
lean_dec(v_v_82_);
v___x_87_ = lean_array_fset(v_xs_x27_84_, v_head_75_, v___x_86_);
v_as_x27_73_ = v_tail_76_;
v_b_74_ = v___x_87_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg___boxed(lean_object* v_buckets_89_, lean_object* v_as_x27_90_, lean_object* v_b_91_){
_start:
{
lean_object* v_res_92_; 
v_res_92_ = lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg(v_buckets_89_, v_as_x27_90_, v_b_91_);
lean_dec(v_as_x27_90_);
lean_dec(v_buckets_89_);
return v_res_92_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_histogram(lean_object* v_xs_93_, lean_object* v_buckets_94_){
_start:
{
lean_object* v___x_95_; lean_object* v_h_96_; lean_object* v___x_97_; 
v___x_95_ = lean_unsigned_to_nat(0u);
lean_inc(v_buckets_94_);
v_h_96_ = lean_mk_array(v_buckets_94_, v___x_95_);
v___x_97_ = lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg(v_buckets_94_, v_xs_93_, v_h_96_);
lean_dec(v_buckets_94_);
return v___x_97_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_histogram___boxed(lean_object* v_xs_98_, lean_object* v_buckets_99_){
_start:
{
lean_object* v_res_100_; 
v_res_100_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m_histogram(v_xs_98_, v_buckets_99_);
lean_dec(v_xs_98_);
return v_res_100_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0(lean_object* v_buckets_101_, lean_object* v_as_102_, lean_object* v_as_x27_103_, lean_object* v_b_104_, lean_object* v_a_105_){
_start:
{
lean_object* v___x_106_; 
v___x_106_ = lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___redArg(v_buckets_101_, v_as_x27_103_, v_b_104_);
return v___x_106_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0___boxed(lean_object* v_buckets_107_, lean_object* v_as_108_, lean_object* v_as_x27_109_, lean_object* v_b_110_, lean_object* v_a_111_){
_start:
{
lean_object* v_res_112_; 
v_res_112_ = lp_lean_x2dpython_x2dworkspace_List_forIn_x27_loop___at___00LeanPythonEmbed_step05_code_m_histogram_spec__0(v_buckets_107_, v_as_108_, v_as_x27_109_, v_b_110_, v_a_111_);
lean_dec(v_as_x27_109_);
lean_dec(v_as_108_);
lean_dec(v_buckets_107_);
return v_res_112_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step05_code_m(uint8_t builtin) {
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
