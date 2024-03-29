#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# 
# Author: Gabriele Girelli
# Email: gigi.ga90@gmail.com
# Version: 2.0.0
# Date: 20171016
# Project: FISH probe condition picking
# Description: select optimal uniFISH 1st and 2nd hybridization conditions
#   for probes composed of oligonucleotides with the following structure:
#   forward-target-reverse-color.
# 
# ------------------------------------------------------------------------------



# ENV VAR ======================================================================

export LC_ALL=C
version="2.0.0"

moddir="`dirname ${BASH_SOURCE}`/../lib/"
if [ "/" != ${moddir:0:1} ]; then moddir="$(pwd)/$moddir"; fi
srcdir="`dirname ${BASH_SOURCE}`/"
if [ "/" != ${srcdir:0:1} ]; then srcdir="$(pwd)/$srcdir"; fi
curdir="$(pwd)/"

# DEPENDENCIES =================================================================

source $moddir/common.lib.sh

# PARAMS =======================================================================

# Help string
helps="
usage: ./find_fish_conditions.single_probe.sh [-h|--help][-v|--verbose][-y]
    [--dtype dtype][--famode mode][--mvalue m][--version][--noplot]
    [--t1 temp][--t1step step][--t1min tmin][--t1max tmax][--fa1 fa]
    [--na1 na][--mg1 mg]
    [--t2 temp][--t2step step][--t2min tmin][--t2max tmax][--fa2 fa]
    [--na2 na][--mg2 mg]
    [-p conc][-u conc][-r pattern][-s struct][-t nthreads][-a|--harmonize]
    -i fasta -o outdir

 Description:
  This script selects optimal uniFISH 1st and 2nd hybridization conditions for
  probes composed of oligonucleotides with the following structure:
   color-forward-target-reverse.
  Takes a fasta file in input, where each sequence is an oligo in a probe. This
  script works on a single probe and considers the provided fasta file as such.

 Notes:
  Monovalent ion (e.g., Na+) concentration must be > 0 M for 2ndary structure
  calculations using OligoArrayAux.

 Mandatory arguments:
  -i fasta        Input fasta file.
  -o outdir       Output folder.

 Optional arguments:
  -h, --help      Show this help page.
  -a, --harmonize Find optimal condition for the provided probes to be used in
                  the same experiment. Thus, only one condition output.
  --noplot        Do not produce any plot.
  -v, --verbose   Verbose mode.
  --version       Print version and stop.
  -y              Do not ask for settings confirmation.
  --dtype type    Duplex type: DNA:DNA, RNA:RNA, DNA:RNA, RNA:DNA.
                  Default: DNA:RNA
  --famode mode   Formamide correction mode: 'mcconaughy' (classic) or 'wright'.
                  Default: mcconaughy.
  --mvalue m      Formamide m-value, either single x value or xL+y format.
                  Only used with wrighte famode. Default: 0.522.
  --t1 temp       Default temperature for 1st hybridization. Default: 37 degC
  --t1step step   Step for 1st hyb. temp. exploration. Default: 0.1 degC
  --t1min tmin    Lower boundary for temperature exploration (1st hybrid.).
                  Default: 32
  --t1max tmax    Upper boundary for temperature exploration (1st hybrid.).
                  Default: 42
  --fa1 conc      Default formamide conc. for 1st hyb. Default: 25 %
  --na1 conc      Monovalent ion conc for 1st hyb. Default: 0.300 M
  --mg1 conc      Divalent ion conc for 1st hyb. Default: 0 M
  --t2 temp       Default temperature for 2nd hybridization. Default: 37 degC
  --t2min tmin    Lower boundary for temperature exploration (2nd hybrid.).
                  Default: 32
  --t2max tmax    Upper boundary for temperature exploration (2nd hybrid.).
                  Default: 42
  --t2step step   Step for 2nd hyb. temp. exploration. Default: 0.1 degC
  --fa2 conc      Default formamide conc. for 2nd hyb. Default: 25%
  --na2 conc      Monovalent ion conc for 2nd hyb. Default: 0.300 M
  --mg2 conc      Divalent ion conc for 1st hyb. Default: 0 M
  -p conc         Probe concentration. Default: 1e-6 M
  -r pattern      Regular expression for probe name identification.
                  Note: the regular expression output should be a substring of
                        the input fasta header.
                  Default: s/^[>\ ]*([^:]*):.*/\\1/
  -s struct       Comma separated color,forward,target,reverse length in nt.
                  Default: 20,20,30,20
  -t nthreads     Number of threads for parallelization. GNU parallel is
                  required for parallelization to occur.
  -u conc         Universal (labeled) oligo concentration. Default: 1e-6 M
"

# Default values
t1=37
t1step=0.1
t1min=32
t1max=42
fa1=25
na1=0.3
mg1=0
t2=37
t2step=0.1
t2min=32
t2max=42
fa2=25
na2=0.3
mg2=0
probe_conc=0.000001
uni_conc=0.000001
probe_regexp="s/^[>\ ]*([^:]*):.*/\\1/"
verbose=false
dtype="DNA:RNA"
fa_mode="mcconaughy"
fa_mvalue=0.522
struct="20,20,30,20"
nthreads=1
ask=true
harmonize=false
doplot=true

# Set option parsing strings
opt_name="find_fish_conditions.sh"
opt_short="hvyai:o:u:p:s:t:r:"
opt_long="help,verbose,dtype:,famode:,mvalue:,t1:,t1step:,t1min:,t1max:,fa1:,"
opt_long=$opt_long"na1:,mg1:,t2:,t2step:,t2min:,t2max:,fa2:,na2:,mg2:,"
opt_long=$opt_long"harmonize,version,noplot"

# Parse options
CMD="$0 $@"
TEMP=`getopt -o $opt_short --longoptions $opt_long -n $opt_name -- "$@"`
eval set -- "$TEMP"
while true ; do
  case "$1" in
    -h| --help) # Print help page
      echo -e "$helps"
    exit 0 ;;
    --noplot) # No plot mode
      doplot=false
    shift ;;
    --version) # Print version
      echo "find_fish_conditions.sh v$version"
    exit 0 ;;
    -a| --harmonize) # Harmonize probe conditions mode
      harmonize=true
    shift ;;
    --dtype) # Duplex type
      dtype="$2"
    shift 2 ;;
    --famode) # FA correction mode
      if [ "wright" == "$2" -o "mcconaughy" == "$2" ]; then fa_mode="$2"; else
        msg="$helps\n!!!ERROR! --famode possible values are"
        msg="$msg 'mcconaughy' and 'wright'."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --famvalue) # FA m-value
      fa_mvalue="$2"
    shift 2 ;;
    --t1) # 1st hybr. temp.
      if (( $(bc <<< "$2 >= 0") )); then t1="$2"; else
        msg="$helps\n!!!ERROR! --t1 cannot be lower than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t1step) # 1st hybr. temp. step
      if (( $(bc <<< "$2 > 0") )); then t1step=$2; else
        msg="$helps\n!!!ERROR! --t1step must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t1min) # 1st hybr. temp. lower boundary of exploration space
      if (( $(bc <<< "$2 > 0") )); then t1min=$2; else
        msg="$helps\n!!!ERROR! --t1min must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t1max) # 1st hybr. temp. lower boundary of exploration space
      if (( $(bc <<< "$2 > 0") )); then t1max=$2; else
        msg="$helps\n!!!ERROR! --t1max must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --fa1) # 1st hybr. formamide conc.
      if (( $(bc <<< "$2 >= 0") )); then fa1=$2; else
        msg="$helps\n!!!ERROR! --fa1 must be higher than or equal to 0 %."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --na1) # 1st hybr. monovalent ion conc.
      if (( $(bc <<< "$2 > 0") )); then na1=$2; else
        msg="$helps\n!!!ERROR! --na1 must be higher than 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --mg1) # 1st hybr. divalent ion conc.
      if (( $(bc <<< "$2 >= 0") )); then mg1=$2; else
        msg="$helps\n!!!ERROR! --mg1 must be higher than or equal to 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t2) # 2nd hybr. temp.
      if (( $(bc <<< "$2 >= 0") )); then t2="$2"; else
        msg="$helps\n!!!ERROR! --t2 cannot be lower than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t2step) # 2nd hybr. temp. step
      if (( $(bc <<< "$2 > 0") )); then t2step=$2; else
        msg="$helps\n!!!ERROR! --t2step must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t2min) # 2nd hybr. temp. lower boundary of exploration space
      if (( $(bc <<< "$2 > 0") )); then t2min=$2; else
        msg="$helps\n!!!ERROR! --t2min must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --t2max) # 2nd hybr. temp. lower boundary of exploration space
      if (( $(bc <<< "$2 > 0") )); then t2max=$2; else
        msg="$helps\n!!!ERROR! --t2max must be higher than 0 degC."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --fa2) # 2nd hybr. formamide conc.
      if (( $(bc <<< "$2 >= 0") )); then fa2=$2; else
        msg="$helps\n!!!ERROR! --fa2 must be higher than or equal to 0 %."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --na2) # 2nd hybr. monovalen ion conc.
      if (( $(bc <<< "$2 > 0") )); then na2=$2; else
        msg="$helps\n!!!ERROR! --na2 must be higher than 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    --mg2) # 2nd hybr. divalent ion conc.
      if (( $(bc <<< "$2 >= 0") )); then mg2=$2; else
        msg="$helps\n!!!ERROR! --mg2 must be higher than or equal to 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    -i) # Input fasta
      if [ -e "$2" ]; then fain_path="$2"; else
        msg="$helps\n!!!ERROR! Invalid -i option."
        msg="$msg\n          File not found: $2\n"
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    -o) # Output folder
      outdir="$2"
    shift 2 ;;
    -p) # Probe concentration
      if (( $(bc <<< "$2 > 0") )); then probe_conc=$2; else
        msg="$helps\n!!!ERROR! -p must be higher than 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    -r) # Probe ID pattern
      probe_regexp="$2"
    shift 2 ;;
    -s) # Probe structure
      struct="$2"
    shift 2 ;;
    -t) # Number of thread sfor parallelization
      if (( $(bc <<< "0 < $2") )); then nthreads=$2; else
        msg="$helps\n!!!ERROR! -t must be higher than 0."
        echo -e "$msg"; exit 1
      fi
    shift 2;;
    -u) # Universal oligo concentration
      if (( $(bc <<< "$2 > 0") )); then uni_conc=$2; else
        msg="$helps\n!!!ERROR! -u must be higher than 0 M."
        echo -e "$msg"; exit 1
      fi
    shift 2 ;;
    -v | --verbose)
      # Verbose mode on
      verbose=true
    shift ;;
    -y) # Ask for confirmation
    ask=false
    shift ;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit 1 ;;
  esac
done

# Check that metl.pl is installed
if [ ! -x "$(command -v melt.pl)" ]; then
  echo -e "fish-conditions requires OligoArrayAux melt.pl script to work."
  exit 1
fi
if [ 1 -lt $nthreads -a ! -x "$(command -v parallel)" ]; then
  echo -e "fish-conditions requires GNU parallel to parallelize."
  exit 1
else
  maxthreads=$(parallel --number-of-cores)
  if [ $nthreads -gt $maxthreads ]; then
    echo -e "Cannot use more than $maxthreads threads."
    exit 1
  fi
fi

# Check mandatory options
if [ -z "$fain_path" ]; then
  echo -e "$helps\n!!! ERROR! Missing mandatory -i option.\n"
  exit 1
fi
if [ -z "$outdir" ]; then
  echo -e "$helps\n!!! ERROR! Missing mandatory -o option.\n"
  exit 1
fi

# Additional manipulations
IFS=',' read -r -a astruct <<< "$struct"
if [ ${#astruct[@]} -ne 4 ]; then
  msg="""$helps\n !!! ERROR!"
  msg="$msg This script expect a structure of the form:"
  msg="$msg color-forward-target-reverse."
  msg="$msg The provided structure does not match the expected one: $struct"
  echo -e "$msg"
  exit 1
fi
exp_size=0
frag_start=(0)
for len in ${astruct[@]}; do
  if [ $len -le 0 -o -z "$len" ]; then
    msg="$helps\n!!! ERROR! Every structure part must be longer than 0: $struct"
    echo -e "$msg\n"
    exit 1
  fi
  exp_size=$(bc <<< "$exp_size + $len")
  frag_start+=($exp_size)
done

# Plotting mode
if $doplot; then
  setplot=""
else
  setplot="--noplot"
fi

# Make paths absolute
if [ "/" != ${fain_path:0:1} ]; then fain_path=$(pwd)/"$fain_path"; fi
if [ "/" != ${outdir:0:1} ]; then outdir=$(pwd)/$outdir/; fi

# Print options
opt_string="
#------------ GENERAL ------------#

   Probe pattern : $probe_regexp
     Input fasta : $fain_path
   Output folder : $outdir
         Verbose : $verbose
   FA correction : $fa_mode
       Structure : $struct
   Expected size : $exp_size
         Threads : $nthreads
       Harmonize : $harmonize
            Plot : $doplot

#------- 1st HYBRIDIZATION -------#

            Type : $dtype
         [probe] : $probe_conc M
     Temperature : $t1 degC
      Temp. step : $t1step degC
     Temp. range : $t1min - $t1max degC
            [FA] : $fa1 %
           [Na+] : $na1 M
          [Mg2+] : $mg1 M

#------- 2nd HYBRIDIZATION -------#

            Type : DNA:DNA
           [uni] : $uni_conc M
     Temperature : $t2 degC
      Temp. step : $t2step degC
     Temp. range : $t2min - $t2max degC
            [FA] : $fa2 %
           [Na+] : $na2 M
          [Mg2+] : $mg2 M

#---------------------------------#
"
# Ask confirmation
if $ask; then confirm_settings "$opt_string"; fi

# Check output folder
if $ask; then confirm_overwrite $outdir; fi

# RUN ==========================================================================

# Create output directory if missing
mkdir -p "$outdir"

# Output settings
echo -e "$opt_string" > $outdir/settings.txt

# Save command line
echo -e "$CMD" > "$outdir/CMD"

# Copy input fasta to output directory and convert to proper format
cat "$fain_path" | tr '\r' '\n' | tr -s '\n' > $outdir/input.fa

# Identify probes --------------------------------------------------------------
plist=($(cat "$outdir/input.fa" | grep ">" | \
  sed -E "$probe_regexp" | sort | uniq))
echo -e "Found ${#plist[@]} probes."
if (( $(bc <<< "0 == ${#plist[@]}") )); then exit 0; fi

# Iterate through probes -------------------------------------------------------

if $harmonize; then
  # HARMONIZE PROBES MODE #

  # Run single probe script
  $srcdir/find_fish_conditions.single_probe.sh -y --dtype "$dtype" \
    --famode "$fa_mode" --mvalue "$fa_mvalue" \
    --t1 "$t1" --t1step "$t1step" --t1min "$t1min" --t1max "$t1max" \
    --fa1 "$fa1" --na1 "$na1" --mg1 "$mg1" \
    --t2 "$t2" --t2step "$t2step" --t2min "$t2min" --t2max "$t2max" \
    --fa2 "$fa2" --na2 "$na2" --mg2 "$mg2" \
    -p "$probe_conc" -u "$uni_conc" -s "$struct" -n "Harmonized" \
    -t "$nthreads" -r "$probe_regexp" $setplot \
    -i "$outdir/input.fa" -o "$outdir"
else
  # SINGLE PROBE MODE #

  for probe_name in ${plist[@]}; do
    echo -e "Working on probe '$probe_name'"

    # Create single_probe output directory
    probe_dir="$outdir/single_probes/$probe_name"
    mkdir -p "$probe_dir"

    # Aggregate fasta sequences by header
    tabchar=$'\t'
    fa_oneline=$(echo "$(cat $outdir/input.fa)" | tr "\n" "\t" | \
        sed -E "s/[[:blank:]]([ATGCUatgcu]*)[[:blank:]]([^>])/$tabchar\1\2/g" \
        | tr "\t" "\n")

    # Output single-probe fasta
    echo "$fa_oneline" | paste - - | grep "$probe_name" \
      | tr '\t' '\n' > "$probe_dir/input.fa"

    # Save command line
    echo -e "$srcdir/find_fish_conditions.single_probe.sh -y --dtype '$dtype' \
      --famode '$fa_mode' --mvalue '$fa_mvalue' \
      --t1 '$t1' --t1step '$t1step' --t1min '$t1min' --t1max '$t1max' \
      --fa1 '$fa1' --na1 '$na1' --mg1 '$mg1' \
      --t2 '$t2' --t2step '$t2step' --t2min '$t2min' --t2max '$t2max' \
      --fa2 '$fa2' --na2 '$na2' --mg2 '$mg2' \
      -p '$probe_conc' -u '$uni_conc' -s '$struct' -n '$probe_name' \
      -t '$nthreads' $setplot \
      -i '$probe_dir/input.fa' -o '$probe_dir'
    " > "$probe_dir/CMD"

    # Run single probe script
    $srcdir/find_fish_conditions.single_probe.sh -y --dtype "$dtype" \
      --famode "$fa_mode" --mvalue "$fa_mvalue" \
      --t1 "$t1" --t1step "$t1step" --t1min "$t1min" --t1max "$t1max" \
      --fa1 "$fa1" --na1 "$na1" --mg1 "$mg1" \
      --t2 "$t2" --t2step "$t2step" --t2min "$t2min" --t2max "$t2max" \
      --fa2 "$fa2" --na2 "$na2" --mg2 "$mg2" \
      -p "$probe_conc" -u "$uni_conc" -s "$struct" -n "$probe_name" \
      -t "$nthreads" $setplot \
      -i "$probe_dir/input.fa" -o "$probe_dir"
  done
fi

# END ==========================================================================

################################################################################
