COQLIB:=$(shell $(COQBIN)coqc -where)/
BACKUPDIR:="user-contrib/tactician-stdlib-backup/"
VFILES:=$(shell cd $(COQLIB) && find theories plugins user-contrib/Ltac2 -name *.v | \
		grep -vE 'Classes/Morphisms\.v|Classes/CMorphisms\.v|Classes/Morphisms_Prop\.v|Classes/CEquivalence\.v|Numbers/Cyclic/Int63/Int63\.v|Init/.*\.v|Numbers/NatInt/NZDiv\.v|FSets/FMapFacts\.v|FSets/FSetBridge\.v|Lists/ListSet\.v|MSets/MSetFacts\.v|MSets/MSetList\.v|MSets/MSetPositive\.v|MSets/MSetWeakList\.v|Reals/ROrderedType\.v|Reals/Ratan\.v|theories/micromega/ZArith_hints\.v|user-contrib/Ltac2/Control\.v|user-contrib/Ltac2/Fresh\.v')
VOFILES:=$(subst .v,X.vo,$(VFILES))
BENCHFILES:=$(VFILES:.v=.bench.vo)

BENCHMARK?=
INFERENCES?=
BENCHMARKSTRING := $(if $(BENCHMARK),Set Tactician Benchmark $(BENCHMARK).,)
BENCHMARKSTRING += $(if $(INFERENCES), Set Tactician Benchmark Inferences $(INFERENCES).,)
BENCHMARKFLAG := $(if $(BENCHMARK),-l Benchmark.v,)

ifeq ($(TACTICIANTHEORIES),)
TACTICIANTHEORIES := $(COQLIB)user-contrib/Tactician
endif
ifeq ($(TACTICIANSRC),)
TACTICIANSRC := $(COQLIB)user-contrib/Tactician
endif

# TODO: This is ugly, but since there are no .mllib source files installed by Coq,
# coqdep cannot find plugin dependencies. Therefore, we just have to link all the .cmxs
# files into the build dir.
PLUGINFILES=$(shell cd $(COQLIB) && find plugins user-contrib/Ltac2 user-contrib/Tactician -name *.cmxs)
BOOTCOQC=$(COQBIN)coqc -q -I $(TACTICIANSRC) -R $(TACTICIANTHEORIES) Tactician \
         -rifrom Tactician Ltac1.Record

all: $(VOFILES) $(subst .v,X.v,$(VFILES)) $(PLUGINFILES)

install: backup install-recompiled

backup:
	for f in $(VOFILES); do\
		echo "Backing up $$f";\
		mkdir --parents $(COQLIB)$(BACKUPDIR)$$(dirname $$f);\
		cp -p $(COQLIB)$$f $(COQLIB)$(BACKUPDIR)$$f;\
	done

install-recompiled:
	for f in $(VOFILES); do\
		echo "Installing $$f";\
		cp -p $$f $(COQLIB)$$f;\
	done

restore:
	for f in $(VOFILES); do\
		echo "Restoring $$f";\
		cp -p $(COQLIB)$(BACKUPDIR)$$f $(COQLIB)$$f;\
	done

clean:
	rm -rf theories plugins user-contrib .vfiles.d Benchmark.v
	find . -name *.feat -name *.bench -delete

theories/Init/%.vo theories/Init/%.glob: theories/Init/%X.v $(PLUGINFILES)
	@rm -f $*.glob
	@echo "coqc $<"
	@$(BOOTCOQC) -R theories Coq $<

%X.vo %.glob: %X.v $(PLUGINFILES)
	@rm -f $*.glob
	@echo "coqc $<"
	@touch $(<:.v=.bench.vo)
	$(BOOTCOQC) -R theories Coq $<

# We compile a second time in case of benchmarking, for performance reasons (due to improved parallelism)
# theories/Init/%.bench.vo: theories/Init/%.v Benchmark.v
# 	@echo "coqc benchmark $<"
# 	@touch $(<:.v=.bench.vo)
# 	@bwrap --dev-bind / / --file ${CURDIR}/$(<:.v=.bench.vo) ${CURDIR}/$(<:.v=.vo) \
# 		$(BOOTCOQC) -noinit -R theories Coq $<

# %.bench.vo: %X.v
# 	@echo "coqc benchmark $<"
# 	@touch $(<:.v=.bench.vo)
# 	$(BOOTCOQC) -R theories Coq $<

theories/Init/%.v:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	cp $(COQLIB)$@ $@

%X.v %.cmxs:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	ln -s -T $(COQLIB)$(subst X.v,.v,$@) $@

# TODO: Also ugly, see https://github.com/coq/coq/pull/11851
Benchmark.v: force
	@touch -a $@
	@if [ "$$(cat $@)" != "$(BENCHMARKSTRING)" ]; then echo "$(BENCHMARKSTRING)" > $@; fi

.SECONDARY : $(PLUGINFILES)

# -include .vfiles.d

# TODO: We have to redirect error, because of https://github.com/coq/coq/issues/11850
TOTARGET = > "$@" 2> /dev/null || (RV=$$?; rm -f "$@"; exit $${RV})

USERCONTRIBDIRS:=\
	Ltac2 Tactician
PLUGINDIRS:=\
  omega		micromega \
  setoid_ring 	extraction \
  cc 		funind 		firstorder 	derive \
  rtauto 	nsatz           syntax          btauto \
  ssrmatching	ltac		ssr

# .vfiles.d: $(VFILES) $(PLUGINFILES)
# 	@echo "coqdep"
# 	@$(COQBIN)coqdep -boot -dyndep no -R theories Coq \
#                          -R plugins Coq \
#                          -Q user-contrib "" \
#                          $(addprefix -I plugins/, $(PLUGINDIRS)) \
#                          $(addprefix -I user-contrib/,$(USERCONTRIBDIRS)) \
#                          $(VFILES) $(TOTARGET)

.PHONY: all clean force
