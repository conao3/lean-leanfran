// Lean compiler output
// Module: LeanPythonEmbed.step01.code.m
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
lean_object* lean_string_append(lean_object*, lean_object*);
lean_object* lean_nat_mul(lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* lean_nat_mod(lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
lean_object* l_List_range(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_double(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_double___boxed(lean_object*);
static const lean_string_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "Hello, "};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__0_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "!"};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__1 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__1_value;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_isPrime(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_isPrime___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_double(lean_object* v_n_1_){
_start:
{
lean_object* v___x_2_; lean_object* v___x_3_; 
v___x_2_ = lean_unsigned_to_nat(2u);
v___x_3_ = lean_nat_mul(v___x_2_, v_n_1_);
return v___x_3_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_double___boxed(lean_object* v_n_4_){
_start:
{
lean_object* v_res_5_; 
v_res_5_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_double(v_n_4_);
lean_dec(v_n_4_);
return v_res_5_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet(lean_object* v_name_8_){
_start:
{
lean_object* v___x_9_; lean_object* v___x_10_; lean_object* v___x_11_; lean_object* v___x_12_; 
v___x_9_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__0));
v___x_10_ = lean_string_append(v___x_9_, v_name_8_);
v___x_11_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___closed__1));
v___x_12_ = lean_string_append(v___x_10_, v___x_11_);
return v___x_12_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet___boxed(lean_object* v_name_13_){
_start:
{
lean_object* v_res_14_; 
v_res_14_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_greet(v_name_13_);
lean_dec_ref(v_name_13_);
return v_res_14_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact(lean_object* v_x_15_){
_start:
{
lean_object* v_zero_16_; uint8_t v_isZero_17_; 
v_zero_16_ = lean_unsigned_to_nat(0u);
v_isZero_17_ = lean_nat_dec_eq(v_x_15_, v_zero_16_);
if (v_isZero_17_ == 1)
{
lean_object* v___x_18_; 
v___x_18_ = lean_unsigned_to_nat(1u);
return v___x_18_;
}
else
{
lean_object* v_one_19_; lean_object* v_n_20_; lean_object* v___x_21_; lean_object* v___x_22_; lean_object* v___x_23_; 
v_one_19_ = lean_unsigned_to_nat(1u);
v_n_20_ = lean_nat_sub(v_x_15_, v_one_19_);
v___x_21_ = lean_nat_add(v_n_20_, v_one_19_);
v___x_22_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact(v_n_20_);
lean_dec(v_n_20_);
v___x_23_ = lean_nat_mul(v___x_21_, v___x_22_);
lean_dec(v___x_22_);
lean_dec(v___x_21_);
return v___x_23_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact___boxed(lean_object* v_x_24_){
_start:
{
lean_object* v_res_25_; 
v_res_25_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_fact(v_x_24_);
lean_dec(v_x_24_);
return v_res_25_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0(lean_object* v_n_26_, lean_object* v_x_27_){
_start:
{
if (lean_obj_tag(v_x_27_) == 0)
{
uint8_t v___x_28_; 
v___x_28_ = 1;
return v___x_28_;
}
else
{
lean_object* v_head_29_; lean_object* v_tail_30_; lean_object* v___x_31_; lean_object* v___x_32_; lean_object* v___x_33_; lean_object* v___x_34_; uint8_t v___x_35_; 
v_head_29_ = lean_ctor_get(v_x_27_, 0);
v_tail_30_ = lean_ctor_get(v_x_27_, 1);
v___x_31_ = lean_unsigned_to_nat(2u);
v___x_32_ = lean_nat_add(v_head_29_, v___x_31_);
v___x_33_ = lean_nat_mod(v_n_26_, v___x_32_);
lean_dec(v___x_32_);
v___x_34_ = lean_unsigned_to_nat(0u);
v___x_35_ = lean_nat_dec_eq(v___x_33_, v___x_34_);
lean_dec(v___x_33_);
if (v___x_35_ == 0)
{
uint8_t v___x_36_; 
v___x_36_ = lean_nat_dec_le(v___x_31_, v_n_26_);
if (v___x_36_ == 0)
{
return v___x_36_;
}
else
{
v_x_27_ = v_tail_30_;
goto _start;
}
}
else
{
uint8_t v___x_38_; 
v___x_38_ = 0;
return v___x_38_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0___boxed(lean_object* v_n_39_, lean_object* v_x_40_){
_start:
{
uint8_t v_res_41_; lean_object* v_r_42_; 
v_res_41_ = lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0(v_n_39_, v_x_40_);
lean_dec(v_x_40_);
lean_dec(v_n_39_);
v_r_42_ = lean_box(v_res_41_);
return v_r_42_;
}
}
LEAN_EXPORT uint8_t lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_isPrime(lean_object* v_n_43_){
_start:
{
lean_object* v___x_44_; uint8_t v___x_45_; 
v___x_44_ = lean_unsigned_to_nat(2u);
v___x_45_ = lean_nat_dec_le(v___x_44_, v_n_43_);
if (v___x_45_ == 0)
{
return v___x_45_;
}
else
{
lean_object* v___x_46_; lean_object* v___x_47_; uint8_t v___x_48_; 
v___x_46_ = lean_nat_sub(v_n_43_, v___x_44_);
v___x_47_ = l_List_range(v___x_46_);
v___x_48_ = lp_lean_x2dpython_x2dworkspace_List_all___at___00LeanPythonEmbed_step01_code_m_isPrime_spec__0(v_n_43_, v___x_47_);
lean_dec(v___x_47_);
return v___x_48_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_isPrime___boxed(lean_object* v_n_49_){
_start:
{
uint8_t v_res_50_; lean_object* v_r_51_; 
v_res_50_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m_isPrime(v_n_49_);
lean_dec(v_n_49_);
v_r_51_ = lean_box(v_res_50_);
return v_r_51_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step01_code_m(uint8_t builtin) {
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
