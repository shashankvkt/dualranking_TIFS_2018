%{

This code describes the re-ranking method as described in the paper to
obtain an optimized ranklist.

Input: Initial score of Dict align and any other baseline method obtained
by taking the distance between a given probe and all gallery elements.

Process: computes the strongly similiar, dissimilar and neutral gallery
         elements. A fuzzy fusion technique is also implemented in the
         process. We obtain an optimized ranklist which is used to compute
         the rank-k% accuracy.

Output: Rank-k% +/- std., where k = 1,5,10,15,20.


Code written by : Shashanka V. (shashank.v@Knights.ucf.edu)

NOTE:- The notations used here and that in the paper may
differ..but the formulations are exactly the same. You may use your own
notations for convinience.
%}

clear all;close all;clc;

% evaluation for all 10 folds (evaluation protocol as descibed in CASIA NIR-VIS 2.0 database)
for K_SET = 1:10
    K_SET
    
    % get the testing labels of the probe and gallery
    eval(sprintf('load /media/shashank/Elements/IISC/shashank/codes/data/LowResNIR_casiatest_vggOriginalfeats_pool5fc67_fold%d gallery_id nirp_id',K_SET));
    
    % Load the scores (Dict Align and any other baseline) of both the baseline algorithms
    eval(sprintf('load ../Scores/WACV/scoreDictAlign_fold%d',K_SET)); % score of Dict Align
    eval(sprintf('load ../Test_Data/WACV/testData_DictAlign_fold%d',K_SET)); % Gallery of Algo 1
    eval(sprintf('load ../Scores/CBFD/scoreCBFD_fold%d',K_SET)); % score of anyother baseline
    
    
    % Get the gallery-to-gallery similarity score using Algo 1 - used during backward requery
    dist_gal = pdist2(Alpha_h.',Alpha_h.','cosine');
    
    % parameters used in this re-ranking algorithm
    rank1 = 0;
    nn = 40; 
    nn2 = 150;
    alpha =0.6;
    
    alpha1 = 1.9;
    gamma = 0.001;
    gamma2= 10^-5;
    
    
    % Initialization of Fuse_Sc (refer paper)
    sim_score_2 = zeros(1,length(gallery_id));
    
    num_probe = size(score_wacv,1); % no. of probe elements
    
    % Normalize the initial scores.
    score_wacv = normc(score_wacv);
    score_cbfd = normc(score_cbfd);


    for i =1:num_probe
        i
        temp = [1:length(gallery_id)];
        rank_list1 = score_wacv(i,:);
        rank_list2 = score_cbfd(i,:);
        
        [~,sort_rl1] = sort(rank_list1,'ascend'); % sort the scores to obtain the ranklist for Dict Align
        [~,sort_rl2] = sort(rank_list2,'ascend'); % sort the scores to obtain the ranklist for any other baseline method (here CBFD)
        
        strongly_similar = intersect(sort_rl1(1:nn),sort_rl2(1:nn));  % compute the stronly similar gallery elements
        strongly_dissimilar = intersect(sort_rl1(end-nn2+1:end),sort_rl2(end-nn2+1:end));  % compute the stronly dissimilar gallery elements
        strongly_neutral = intersect(sort_rl1(50:100),sort_rl2(50:100));  % compute the stronly neutral gallery elements
        
        % taking gallery from r1 to affect rl2
        for j = 1:length(strongly_similar)
            %similar
            sim_probe_2 = find(strongly_similar(j) == sort_rl1); % get rank of gallery in forward query
            gallery = strongly_similar(j); % consider the jth element as the psuedo-probe
            gal_excl_sim = strongly_similar(strongly_similar ~= gallery); % remove that gallery element from the gallery set
            dist_new_sim = [dist_gal(gallery,gal_excl_sim) score_wacv(i,gallery)]; %create a score list with the probe p added at the end of the list.
            [~,idx_2] = sort(dist_new_sim,'ascend'); %sort this backward requieried score to obtain its corresponding ranklist
            sim_gal_2 = find(idx_2 == length(strongly_similar)); % find the rank of the psuedo-probe in this backward requried ranklist.
            
            % dissimilar
            % compute the number of common dissimilar elements as described in the paper
            gal_excl_rest = sort_rl1(sort_rl1 ~= gallery);
            dist_new_rest = [dist_gal(gallery,gal_excl_rest) score_cbfd(i,gallery)];
            [~,idx_rest] = sort(dist_new_rest,'ascend');
            dissimilar_ele = idx_rest(end-nn2+1:end);
            common_dissimilar = length(intersect(strongly_dissimilar,dissimilar_ele));
            
            %neutral
            % compute the number of common neutral elements as described in the paper
            neutral_ele = idx_rest(50:200);
            common_neutral = length(intersect(neutral_ele,strongly_neutral));
            
            
            sim_score = gamma/(sim_probe_2*sim_gal_2); % Compute the Similarity score
            dissim_score = (exp(-(common_dissimilar))); % Compute the dissimilarity score
            neutral_score = gamma2*(exp(-(common_neutral))); % Compute the neutral score
            
            complete_score = ((sim_score.^alpha1) + (dissim_score.^alpha1) + (neutral_score.^alpha1))/3; % Fuse the scores using fuzzy aggregation
            
            %replace the scores of the gallery elements in the ranklist of
            %Algo 2 with this new score
            sim_score_2(strongly_similar(j)) = complete_score;%(sim_score + dissim_score);
        end
        
        temp([strongly_similar]) = [];
        sim_score_2(temp) = rank_list2(temp);
        
        % Fuse the new ranklist of RL2 with its unchanged score using fuzzy aggregation 
        new_rl2 = 0.5*(((rank_list2.^alpha) + (sim_score_2.^alpha)).^(1/alpha));

        
        %compute final score using weighted sum between ranklist of Algo 1
        %and modified ranklist of Algo 2 for each probe
        
        final_dist(i,:) =  0.3*new_rl2 + 0.7*rank_list1;
 
    end

    % compute the cmc list for this re-ranking method
    cmcs = zeros(1,358);
    final_dist = normc(final_dist);
    disp(['Compute the Accuracy: '])
    for i = 1:size(final_dist,1)
        dist = final_dist(i,:);
        [~,sortIdx] = sort(dist,'ascend');
        
        gtLabel = nirp_id(i);
        gal_label = gallery_id(sortIdx);
        pos = find(gal_label == gtLabel);
        cmcs(pos:end) = cmcs(pos:end) + 1;
    end
    cmc(K_SET,:) = 100*cmcs/size(final_dist,1);  % comment this stmt for single fold evalution
%     cmc = 100*cmcs/size(final_dist,1);         % uncomment this stmt for single fold evalution
    disp(['rank-1: ', num2str(cmc(K_SET,1))])    % comment this stmt for single fold evalution
%     disp(['rank-1: ', num2str(cmc(1))])        % uncomment this stmt for single fold evalution


    clear final_dist    
end

% Compute the Mean and Std for All 10 folds...Comment this section for
% single fold evalution
rank_ks = [1,5,10,15,20];
for rank_k = 1:length(rank_ks)
    recogNIR_VIS = cmc(:,rank_ks(rank_k));
    numeratorVal=0;
    for temp1 = 1:10
        numeratorVal = numeratorVal+(recogNIR_VIS(temp1)-mean(recogNIR_VIS))^2;
    end
    std_value_DA = sqrt(numeratorVal/9);
    result_mean_var(rank_k,:) = [mean(recogNIR_VIS) std_value_DA];
end
result_mean_var
% comment till here for single fold evaluation



