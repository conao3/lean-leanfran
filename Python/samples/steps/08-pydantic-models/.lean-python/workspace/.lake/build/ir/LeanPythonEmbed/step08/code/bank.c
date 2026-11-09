// Lean compiler output
// Module: LeanPythonEmbed.step08.code.bank
// Imports: public import Init public meta import Init public import LeanPythonModels.step08.code
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
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank_transfer(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank_transfer___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank_transfer(lean_object* v_a_1_, lean_object* v_b_2_, lean_object* v_amount_3_){
_start:
{
lean_object* v_owner_4_; lean_object* v_balance_5_; uint8_t v___x_6_; 
v_owner_4_ = lean_ctor_get(v_a_1_, 0);
v_balance_5_ = lean_ctor_get(v_a_1_, 1);
v___x_6_ = lean_nat_dec_le(v_amount_3_, v_balance_5_);
if (v___x_6_ == 0)
{
lean_object* v___x_7_; 
v___x_7_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_7_, 0, v_a_1_);
lean_ctor_set(v___x_7_, 1, v_b_2_);
return v___x_7_;
}
else
{
lean_object* v___x_9_; uint8_t v_isShared_10_; uint8_t v_isSharedCheck_26_; 
lean_inc(v_balance_5_);
lean_inc_ref(v_owner_4_);
v_isSharedCheck_26_ = !lean_is_exclusive(v_a_1_);
if (v_isSharedCheck_26_ == 0)
{
lean_object* v_unused_27_; lean_object* v_unused_28_; 
v_unused_27_ = lean_ctor_get(v_a_1_, 1);
lean_dec(v_unused_27_);
v_unused_28_ = lean_ctor_get(v_a_1_, 0);
lean_dec(v_unused_28_);
v___x_9_ = v_a_1_;
v_isShared_10_ = v_isSharedCheck_26_;
goto v_resetjp_8_;
}
else
{
lean_dec(v_a_1_);
v___x_9_ = lean_box(0);
v_isShared_10_ = v_isSharedCheck_26_;
goto v_resetjp_8_;
}
v_resetjp_8_:
{
lean_object* v_owner_11_; lean_object* v_balance_12_; lean_object* v___x_14_; uint8_t v_isShared_15_; uint8_t v_isSharedCheck_25_; 
v_owner_11_ = lean_ctor_get(v_b_2_, 0);
v_balance_12_ = lean_ctor_get(v_b_2_, 1);
v_isSharedCheck_25_ = !lean_is_exclusive(v_b_2_);
if (v_isSharedCheck_25_ == 0)
{
v___x_14_ = v_b_2_;
v_isShared_15_ = v_isSharedCheck_25_;
goto v_resetjp_13_;
}
else
{
lean_inc(v_balance_12_);
lean_inc(v_owner_11_);
lean_dec(v_b_2_);
v___x_14_ = lean_box(0);
v_isShared_15_ = v_isSharedCheck_25_;
goto v_resetjp_13_;
}
v_resetjp_13_:
{
lean_object* v___x_16_; lean_object* v___x_18_; 
v___x_16_ = lean_nat_sub(v_balance_5_, v_amount_3_);
lean_dec(v_balance_5_);
if (v_isShared_15_ == 0)
{
lean_ctor_set(v___x_14_, 1, v___x_16_);
lean_ctor_set(v___x_14_, 0, v_owner_4_);
v___x_18_ = v___x_14_;
goto v_reusejp_17_;
}
else
{
lean_object* v_reuseFailAlloc_24_; 
v_reuseFailAlloc_24_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_24_, 0, v_owner_4_);
lean_ctor_set(v_reuseFailAlloc_24_, 1, v___x_16_);
v___x_18_ = v_reuseFailAlloc_24_;
goto v_reusejp_17_;
}
v_reusejp_17_:
{
lean_object* v___x_19_; lean_object* v___x_21_; 
v___x_19_ = lean_nat_add(v_balance_12_, v_amount_3_);
lean_dec(v_balance_12_);
if (v_isShared_10_ == 0)
{
lean_ctor_set(v___x_9_, 1, v___x_19_);
lean_ctor_set(v___x_9_, 0, v_owner_11_);
v___x_21_ = v___x_9_;
goto v_reusejp_20_;
}
else
{
lean_object* v_reuseFailAlloc_23_; 
v_reuseFailAlloc_23_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_23_, 0, v_owner_11_);
lean_ctor_set(v_reuseFailAlloc_23_, 1, v___x_19_);
v___x_21_ = v_reuseFailAlloc_23_;
goto v_reusejp_20_;
}
v_reusejp_20_:
{
lean_object* v___x_22_; 
v___x_22_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_22_, 0, v___x_18_);
lean_ctor_set(v___x_22_, 1, v___x_21_);
return v___x_22_;
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank_transfer___boxed(lean_object* v_a_29_, lean_object* v_b_30_, lean_object* v_amount_31_){
_start:
{
lean_object* v_res_32_; 
v_res_32_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank_transfer(v_a_29_, v_b_30_, v_amount_31_);
lean_dec(v_amount_31_);
return v_res_32_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonModels_step08_code(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step08_code_bank(uint8_t builtin) {
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
res = initialize_lean_x2dpython_x2dworkspace_LeanPythonModels_step08_code(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
