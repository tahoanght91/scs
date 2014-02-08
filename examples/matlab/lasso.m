clear all

disp('------------------------------------------------------------')
disp('WARNING: this can take a very long time to run.')
disp('It may also crash/run out of memory.')
disp('Set run_sdpt3 = false if you just want to run scs.')
disp('------------------------------------------------------------')

run ../../matlab/cvx_install_scs.m

save_results = false;
run_sdpt3 = false;
run_scs = true;

ns = [3000,10000,30000];
ms = ceil(ns/5);

density = 0.01;

time_pat_cvx = 'Total CPU time \(secs\)\s*=\s*(?<total>[\d\.]+)';

for i = 1:length(ns)
    seedstr = sprintf('scs_lasso_ex_%i',i);
    randn('seed',sum(seedstr));rand('seed',sum(seedstr))

    n=ns(i);
    m=ms(i);
    s=ceil(n/10);
    
    x_true=[randn(s,1);zeros(n-s,1)]; % true sparse signal
    x_true=x_true(randperm(n));
    A=sprandn(m,n,density);
    b = A*x_true + 0.1*randn(m,1); % measurements
    mu = 1;
    
    lasso_prob.x_true{i} = x_true;
    lasso_prob.A{i} = A;
    lasso_prob.b{i} = b;
    lasso_prob.mu{i} = mu;
    lasso_prob.s{i} = s;
    lasso_prob.n{i} = n;
    lasso_prob.m{i} = m;
    if (save_results); save('data/lasso_prob', 'lasso_prob','-v7.3'); end
    
    %%
    if run_scs
        tic
        cvx_begin
        cvx_solver_settings('GEN_PLOTS',1) % only works for 'cvx_solver scs_matlab'
        cvx_solver scs
        variable x_c(n)
        minimize(0.5*sum_square(A*x_c - b) + mu*norm(x_c,1))
        output = evalc('cvx_end')
        toc   
        
        scs_direct.x{i} = x_c;
        scs_direct.obj(i) = 0.5*sum_square(A*x_c - b) + mu*norm(x_c,1);
        scs_direct.output{i} = output;
        
        
        if (save_results); save('data/lasso_scs_direct', 'scs_direct'); end
        
        %%
        
        tic
        cvx_begin
        cvx_solver_settings('USE_INDIRECT',1,'CG_MAX_ITS',2)
        cvx_solver_settings('GEN_PLOTS',1) % only works if 'cvx_solver scs_matlab'
        cvx_solver scs
        variable x_c(n)
        minimize(0.5*sum_square(A*x_c - b) + mu*norm(x_c,1))
        output = evalc('cvx_end')
        toc
        
        scs_indirect.x{i} = x_c;
        scs_indirect.obj(i) = 0.5*sum_square(A*x_c - b) + mu*norm(x_c,1);
        scs_indirect.output{i} = output;
        
        if (save_results); save('data/lasso_scs_indirect', 'scs_indirect'); end
        
    end
    %%
    if run_sdpt3
        try
            tic
            cvx_begin
            cvx_solver sdpt3
            variable x_s(n)
            minimize(0.5*sum_square(A*x_s - b) + mu*norm(x_s,1))
            output = evalc('cvx_end')
            toc
            
            cvx.x{i} = x_s;
            cvx.obj(i) = 0.5*sum_square(A*x_s - b) + mu*norm(x_s,1);
            timing = regexp(output, time_pat_cvx, 'names');
            cvx.time{i} = str2num(timing.total);
            cvx.output{i} = output;
            cvx.err{i} = 0;
            
        catch err
            cvx.err{i} = err;
        end
        
        if (save_results); save('data/lasso_cvx', 'cvx'); end;
        
    end
end
