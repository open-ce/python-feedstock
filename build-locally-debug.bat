set PY_INTERP_DEBUG=yes
call conda activate
conda-build -m ..\..\a\conda_build_config.yaml . --python 3.7
