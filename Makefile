export SDK_SRC_ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

include $(SDK_SRC_ROOT_DIR)/tools/mkenv.mk

.PHONY: all genimage clean distclean 
all: genimage
	@echo "Build K230 CanMV done."

include $(SDK_TOOLS_DIR)/kconfig.mk
include $(SDK_TOOLS_DIR)/genimage.mk

ifeq ($(strip $(filter $(MAKECMDGOALS),clean distclean)),)
$(SDK_SRC_ROOT_DIR)/.config: $(KCONF)
	@make -C $(SDK_APPS_SRC_DIR) gen_kconfig || exit $?
	@$(KCONF) --defconfig $(SDK_SRC_ROOT_DIR)/configs/$(SDK_DEFCONFIG) $(SDK_SRC_ROOT_DIR)/Kconfig || exit $?

$(SDK_SRC_ROOT_DIR)/.config.old: $(SDK_SRC_ROOT_DIR)/.config
	@cp -f $(SDK_SRC_ROOT_DIR)/.config $(SDK_SRC_ROOT_DIR)/.config.old
	@$(KCONF) --syncconfig $(SDK_SRC_ROOT_DIR)/Kconfig || exit $?
endif

.PHONY: menuconfig
menuconfig: $(MCONF) $(SDK_SRC_ROOT_DIR)/.config
	$(call del_mark)
	@make -C $(SDK_APPS_SRC_DIR) gen_kconfig || exit $?
	@$(MCONF) $(SDK_SRC_ROOT_DIR)/Kconfig || exit $?

.PHONY: savedefconfig
savedefconfig: $(KCONF) $(SDK_SRC_ROOT_DIR)/.config
	@make -C $(SDK_APPS_SRC_DIR) gen_kconfig || exit $?
	@$(KCONF) --savedefconfig=$(SDK_SRC_ROOT_DIR)/defconfig $(SDK_SRC_ROOT_DIR)/Kconfig || exit $?

.PHONY: .autoconf
.autoconf: $(SDK_SRC_ROOT_DIR)/.config.old

%_defconfig: $(KCONF)
	$(call del_mark)
	@make -C $(SDK_APPS_SRC_DIR) gen_kconfig || exit $?
	@$(KCONF) --defconfig $(SDK_SRC_ROOT_DIR)/configs/$@ $(SDK_SRC_ROOT_DIR)/Kconfig || exit $?

.PHONY: uboot uboot-clean uboot-distclean
uboot: .autoconf
	@$(MAKE) -C $(SDK_UBOOT_SRC_DIR) all
uboot-clean:
	@$(MAKE) -C $(SDK_UBOOT_SRC_DIR) clean
uboot-distclean:
	@$(MAKE) -C $(SDK_UBOOT_SRC_DIR) distclean


.PHONY: rtsmart rtsmart-clean rtsmart-distclean
rtsmart: .autoconf
	@$(MAKE) -C $(SDK_RTSMART_SRC_DIR) all
rtsmart-clean:
	@$(MAKE) -C $(SDK_RTSMART_SRC_DIR) clean
rtsmart-distclean:
	@$(MAKE) -C $(SDK_RTSMART_SRC_DIR) distclean


.PHONY: opensbi opensbi-clean opensbi-distclean
opensbi: .autoconf rtsmart
	@$(MAKE) -C $(SDK_OPENSBI_SRC_DIR) all
opensbi-clean:
	@$(MAKE) -C $(SDK_OPENSBI_SRC_DIR) clean
opensbi-distclean:
	@$(MAKE) -C $(SDK_OPENSBI_SRC_DIR) distclean


.PHONY: canmv canmv-clean canmv-distclean
canmv: .autoconf
ifeq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_CANMV_SRC_DIR) all
endif
canmv-clean:
ifeq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_CANMV_SRC_DIR) clean
endif
canmv-distclean:
ifeq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_CANMV_SRC_DIR) distclean
endif

.PHONY: app app-clean app-distclean
app: .autoconf
ifneq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_APPS_SRC_DIR) all
endif
app-clean:
ifneq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_APPS_SRC_DIR) clean
endif
app-distclean:
ifneq ($(CONFIG_SDK_ENABLE_CANMV),y)
	@$(MAKE) -C $(SDK_APPS_SRC_DIR) distclean
endif

genimage: $(TOOL_GENIMAGE) uboot rtsmart opensbi canmv app
	@$(SDK_TOOLS_DIR)/gen_image.sh

clean: kconfig-clean $(TOOL_GENIMAGE)-clean uboot-clean rtsmart-clean opensbi-clean
	@echo "Clean done."

distclean: kconfig-distclean $(TOOL_GENIMAGE)-distclean uboot-distclean rtsmart-distclean opensbi-distclean
	$(call del_mark)
	@rm -rf $(SDK_BUILD_DIR)
	@rm -rf $(SDK_SRC_ROOT_DIR)/.config
	@echo "distclean done."


.PHONY: log
log:
ifeq ($(BEAR_EXISTS),yes)
	@bear $(MAKE) 2>&1 | tee log.txt
else
	@$(MAKE) 2>&1 | tee log.txt
endif

.PHONY: dl_toolchain
dl_toolchain:
	@$(MAKE) -f $(SDK_TOOLS_DIR)/toolchain_linux.mk install
	@$(MAKE) -f $(SDK_TOOLS_DIR)/toolchain_rtsmart.mk install
