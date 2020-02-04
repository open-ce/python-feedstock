set PY_INTERP_DEBUG=yes
call conda activate
del /s /q %CONDA_PREFIX%\conda-bld\python
conda-build -m ..\..\a\conda_build_config.yaml . --python 3.7 --no-build-id 2>&1 | C:\msys32\usr\bin\tee %CONDA_PREFIX%\conda-bld\python.log
