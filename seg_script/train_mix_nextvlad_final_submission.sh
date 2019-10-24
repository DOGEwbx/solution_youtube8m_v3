#!/usr/bin/env bash

datapath=/media/linrongc/dream/data/yt8m/frame/3/validate
eval_path=/media/linrongc/dream/data/yt8m/frame/3/validate_strat_split/test
test_path=/media/linrongc/dream/data/yt8m/frame/3/test

model_name=MixNeXtVladModel
parameters="--groups=8 --nextvlad_cluster_size=128 --nextvlad_hidden_size=2048 \
            --expansion=2 --gating_reduction=16  --drop_rate=0.75 --final_drop=0. \
            --mix_number=3 --cl_temperature=20 --cl_lambda=400 --num_gpu=4"

train_dir=parallel4_mix3_nextvlad_x2_1T1_8g_5l2_5drop_128k_2048_80_logistic_final_583k_5f_10ep_20T400_75drop_412_pretrain
pretrain_model=parallel4_mix3_nextvlad_x2_1T1_8g_5l2_5drop_128k_2048_80_logistic_final/model.ckpt-583262
result_folder=results

echo "model name: " $model_name
echo "model parameters: " $parameters

echo "training directory: " $train_dir
echo "data path: " $datapath
echo "evaluation path: " $eval_path
echo "results folder: " $result_folder


python parallel_train.py ${parameters} --model=${model_name} --num_readers=8 --learning_rate_decay_examples 1000000 --num_epochs=10 \
                --video_level_classifier_model=LogisticModel --label_loss=CrossEntropyLoss --start_new_model=False \
                --train_data_pattern=${datapath}/*.tfrecord --train_dir=${train_dir} --frame_features=True \
                --feature_names="rgb,audio" --feature_sizes="1024,128" --batch_size=512 --base_learning_rate=0.0002 \
                --learning_rate_decay=0.8 --l2_penalty=1e-4 --max_step=700000 \
                --final_lambda=400 --final_temperature=20 --segment_labels=True --export_model_steps=2000 \
                --pretrain_model_path=${pretrain_model}

python parallel_eval.py ${parameters} --batch_size=1024 --video_level_classifier_model=LogisticModel --l2_penalty=1e-5\
               --label_loss=CrossEntropyLoss --eval_data_pattern=${eval_path}/*.tfrecord --train_dir ${train_dir} \
               --run_once=True --segment_labels=True --num_gpu=4

mkdir -p $result_folder
python inference.py --output_file ${result_folder}/${train_dir}_test_single_k1000.csv \
                    --input_data_pattern=${test_path}/*.tfrecord --train_dir ${train_dir} \
                    --batch_size=80 --num_readers=8 --segment_labels=True --top_k=1000
