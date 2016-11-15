function net = cnn_init(opts, varargin)

    opts = vl_argparse(opts, varargin) ;

    % default input size
    net.meta.inputSize = [32 32 3] ;
    %net.meta.trainOpts.weightDecay = 0.001 ;
    
    
    % assign the parameters depending on the type of training
    switch opts.trainingType
        % training from scratch
        case 'from-scratch'
            net.meta.trainOpts.numClasses = 2;
            net.meta.trainOpts.errorFunction = opts.errorFunction;
            % copy input parameters
            net.meta.trainOpts.batchSize = opts.learningOpts.from_scratch.batchSize ;
            net.meta.trainOpts.weightDecay = opts.learningOpts.from_scratch.weightDecay ;
            net.meta.trainOpts.minEpochs = opts.learningOpts.from_scratch.min_epochs;
            net.meta.trainOpts.maxEpochs = opts.learningOpts.from_scratch.max_epochs;
            net.meta.trainOpts.convergenceThreshold = opts.learningOpts.from_scratch.convergence_threshold;
            net.meta.trainOpts.decayLRThreshold = opts.learningOpts.from_scratch.decay_lr_threshold;
            net.meta.trainOpts.initialLearningRate = opts.learningOpts.from_scratch.initial_learning_rate;
            net.meta.trainOpts.lrDecayFactor = opts.learningOpts.from_scratch.lr_decay_factor;            
            net.meta.trainOpts.N = opts.learningOpts.from_scratch.N;  
            net.meta.trainOpts.p_dropout = opts.learningOpts.from_scratch.p_dropout;
            net.meta.trainOpts.fc_layer = opts.learningOpts.from_scratch.fc_layer;
        % training on CIFAR-10 for transferring
        case 'transfer'
            net.meta.trainOpts.numClasses = 10;
            % copy input parameters
            net.meta.trainOpts.weightDecay = opts.learningOpts.transfer.weightDecay ;
            net.meta.trainOpts.minEpochs = opts.learningOpts.transfer.min_epochs;
            net.meta.trainOpts.maxEpochs = opts.learningOpts.transfer.max_epochs;
            net.meta.trainOpts.convergenceThreshold = opts.learningOpts.transfer.convergence_threshold;
            net.meta.trainOpts.initialLearningRate = opts.learningOpts.transfer.initial_learning_rate;
            net.meta.trainOpts.lrDecayFactor = opts.learningOpts.transfer.lr_decay_factor;  
            net.meta.trainOpts.N = opts.learningOpts.transfer.N;  
        % fine tuning
        case 'fine-tune'
            net.meta.trainOpts.numClasses = 2;
            % copy input parameters
            net.meta.trainOpts.weightDecay = opts.learningOpts.fine_tune.weightDecay ;
            net.meta.trainOpts.minEpochs = opts.learningOpts.fine_tune.min_epochs;
            net.meta.trainOpts.maxEpochs = opts.learningOpts.fine_tune.max_epochs;
            net.meta.trainOpts.convergenceThreshold = opts.learningOpts.fine_tune.convergence_threshold;
            net.meta.trainOpts.initialLearningRate = opts.learningOpts.fine_tune.initial_learning_rate;
            net.meta.trainOpts.lrDecayFactor = opts.learningOpts.fine_tune.lr_decay_factor;  
            net.meta.trainOpts.N = opts.learningOpts.fine_tune.N;  
    end
    
    lr = [.1 2] ;

    % Define network CIFAR10-quick
    net.layers = {} ;

    % Block 1: CONV + MAX-POOLING + RELU
    net.layers{end+1} = struct('type', 'conv', ...
                               'weights', {{0.01*randn(5,5,3,32, 'single'), zeros(1, 32, 'single')}}, ...
                               'learningRate', lr, ...
                               'stride', 1, ...
                               'pad', 2) ;
    net.layers{end+1} = struct('type', 'pool', ...
                               'method', 'max', ...
                               'pool', [3 3], ...
                               'stride', 2, ...
                               'pad', [0 1 0 1]) ;
    net.layers{end+1} = struct('type', 'relu') ;
    if (net.meta.trainOpts.p_dropout ~= 0)
        net.layers{end+1} = struct('type', 'dropout', 'rate', net.meta.trainOpts.p_dropout);
    end
    
    % Block 2: CONV + RELU + AVG POOL
    net.layers{end+1} = struct('type', 'conv', ...
                               'weights', {{0.05*randn(5,5,32,32, 'single'), zeros(1,32,'single')}}, ...
                               'learningRate', lr, ...
                               'stride', 1, ...
                               'pad', 2) ;
    net.layers{end+1} = struct('type', 'relu') ;
    net.layers{end+1} = struct('type', 'pool', ...
                               'method', 'avg', ...
                               'pool', [3 3], ...
                               'stride', 2, ...
                               'pad', [0 1 0 1]) ; % Emulate caffe                           

    % Block 3: CONV + RELU + POOL
    net.layers{end+1} = struct('type', 'conv', ...
                               'weights', {{0.05*randn(5,5,32,64, 'single'), zeros(1,64,'single')}}, ...
                               'learningRate', lr, ...
                               'stride', 1, ...
                               'pad', 2) ;
    net.layers{end+1} = struct('type', 'relu') ;
    net.layers{end+1} = struct('type', 'pool', ...
                               'method', 'avg', ...
                               'pool', [3 3], ...
                               'stride', 2, ...
                               'pad', [0 1 0 1]) ; % Emulate caffe
                           
    % Block 4: FC + RELU
    net.layers{end+1} = struct('type', 'conv', ...
                               'weights', {{0.05*randn(4,4,64,net.meta.trainOpts.fc_layer, 'single'), zeros(1,net.meta.trainOpts.fc_layer,'single')}}, ...
                               'learningRate', lr, ...
                               'stride', 1, ...
                               'pad', 0) ;
    net.layers{end+1} = struct('type', 'relu') ;

    % Block 5: FC + LOSS
    % Depending of the objective function
    switch opts.objective
        case 'softmax'
            % FC layer
            net.layers{end+1} = struct('type', 'conv', ...
                                       'weights', {{0.05*randn(1,1,net.meta.trainOpts.fc_layer,net.meta.trainOpts.numClasses, 'single'), zeros(1,net.meta.trainOpts.numClasses,'single')}}, ...
                                       'learningRate', .1*lr, ...
                                       'stride', 1, ...
                                       'pad', 0) ;
            % Softmax Loss layer
            net.layers{end+1} = struct('type', 'softmaxloss') ;
        case 'ranking'
            % FC layer
            net.layers{end+1} = struct('type', 'conv', ...
                                       'weights', {{0.05*randn(1,1,net.meta.trainOpts.fc_layer,1, 'single'), zeros(1,1,'single')}}, ...
                                       'learningRate', .1*lr, ...
                                       'stride', 1, ...
                                       'pad', 0) ;
            % Ranking loss layer
            net.layers{end+1} = struct('type', 'rankingloss') ;
        case 'classbalancingsoftmax'
            % FC layer
            net.layers{end+1} = struct('type', 'conv', ...
                                       'weights', {{0.05*randn(1,1,net.meta.trainOpts.fc_layer,net.meta.trainOpts.numClasses, 'single'), zeros(1,net.meta.trainOpts.numClasses,'single')}}, ...
                                       'learningRate', .1*lr, ...
                                       'stride', 1, ...
                                       'pad', 0) ;
            % Class-balancing softmax loss layer
            net.layers{end+1} = struct('type', 'classbalancingsoftmaxloss') ;
            
    end

    % Meta parameters
    % initial learning rate is going to be current learning rate
    net.meta.trainOpts.learningRate = net.meta.trainOpts.initialLearningRate;
    % number of epochs is going to be numEpochs
    net.meta.trainOpts.numEpochs = net.meta.trainOpts.minEpochs;
    
    % Fill in default values
    net = vl_simplenn_tidy(net) ;

    % Switch to DagNN if requested
    switch lower(opts.networkType)
      case 'simplenn'
        % done
      case 'dagnn'
        net = dagnn.DagNN.fromSimpleNN(net, 'canonicalNames', true) ;
        net.addLayer('error', dagnn.Loss('loss', 'classerror'), ...
                 {'prediction','label'}, 'error') ;
      otherwise
        assert(false) ;
    end

end
