function [V,M,X,F,Fval]=MarkoVGGD(A,Y,p,q,opts)
%
% Description:      Solves the augmented inverse problem: Y = A * S * X
%                   using the Variational Garrote with a Markov prior
%                   (MarkoVG).
%
% Input:            Y:  Data matrix of size KxT, where T is the number of
%                       measurements, e.g. time samples.
%                   A:  Design matrix/forward model of size KxN
%                   q:  Probability of changing from inactive to
%                       active state
%                   p:  Probability of changing from active to
%                       inactive state
%                   opts: see 'Settings'
% Output:           X:  Feature matrix of size NxT
%                   M:  Variational mean/expectation of the state 'S'.
%                       Can be thresholded at 0.5 to only keep sources with
%                       high evidence.
%                   V:  The solution matrix; V =X.*M;
%                   F:  The solution's variational free energy
%                   Fval: The variational free energy of a supplied
%                         validation set
%--------------------------References--------------------------------------
% The Variational Garrote was originally presented in 
% Kappen, H. (2011). The Variational Garrote. arXiv Preprint
% arXiv:1109.0486. Retrieved from http://arxiv.org/abs/1109.0486
% and
% Kappen, H.J., & G�mez, V. (2014). The Variational Garrote. Machine
% Learning, 96(3), 269�294. doi:10.1007/s10994-013-5427-7
%
% Preliminary MarkoVG reference 
% Hansen, S.T., & Hansen, L. (2013). EEG Sequence Imaging: A Markov Prior
% for the Variational Garrote. Proceedings of the 3rd NIPS Workshop on
% Machine Learning and Interpretation in Neuroimaging 2013. Retrieved from
% http://orbit.dtu.dk/fedora/objects/orbit:127330/datastreams/file_61f34d92-2e60-4871-8a41-08f1d69f5c47/content

%-----------------------------Author---------------------------------------
% Sofie Therese Hansen, DTU Compute
% March 2016
% -------------------------------------------------------------------------


% Settings:
try max_iter = opts.max_iter; catch; max_iter = 5000; end; % Maximum number of iterations
try m_tol = opts.m_tol; catch; m_tol = 1e-4; end; % Convergence criterium for M
try k_m_conv = opts.k_m_conv; catch; k_m_conv = 2000; end; % Convergence criterium for M
try beta_tol = opts.beta_tol; catch; beta_tol = 1e-3; end; % Convergence criterium for beta
try k_beta_conv = opts.k_beta_conv; catch; k_beta_conv = 1000; end; % Convergence criterium for beta
try eta0 = opts.eta0; catch; eta0=1e-3; end; % Learning rate for gradient descent
try fact = opts.fact; catch;  fact=0.9; end; % Factor in smoothness=-fact*sparsity

[K,N] = size(A);
T = size(Y,2);
% Chi=A'*A/K;
% chi_nn=diag(Chi);
chi_nn = 1/K*sum(A.^2)';
Y = [Y zeros(size(Y,1),1)];T=T+1;
Ytilde = zeros(size(Y));
Beta = Inf(1,max_iter);
% set parameters for prior
Q = [1-q p;q 1-p];
gamt = zeros(1,T);
gamt(1) = log(Q(1,2)/Q(1,1));
gamt(T) = log(Q(2,1)/Q(1,1));
gamt(1:(T-1)) = log(Q(2,1)*Q(1,2)/Q(1,1)^2);
Gam0 = (log((Q(2,2)*Q(1,1))/(Q(2,1)*Q(1,2))))*fact;

% Initialize
m = zeros(N,T);
m = max(m,sqrt(eps));
m = min(m,1-sqrt(eps));
Mits = zeros(max_iter,1);
term = 0;
k = 0;
% Iterate solution until convergence
while k<max_iter&&term==0
    k = k+1;
    for t = 1:T,
        AB = A.*repmat(((m(:,t)./(1-m(:,t)))./chi_nn)',K,1);
        BB = eye(K)+A*AB'/K;
        Ytilde(:,t) = pinv(BB)*Y(:,t);
    end
    sig2 = sum(sum(Ytilde.*Y))/(K*T); %1/beta
    X =((A'*Ytilde).*(1./(1-m))).*repmat(1./(K*chi_nn),1,T);
    X2 = (X.*X);
    h = repmat(-gamt,N,1);
    h(:,2:(T-1))=h(:,2:(T-1))+(-Gam0)*(m(:,1:(T-2))+m(:,3:T));
    h(:,1)=h(:,1)+(-Gam0)*(m(:,2));
    h(:,T)=h(:,T)+(-Gam0)*(m(:,T-1));
    % Gradient descent
    dFdm = h + (K*0.5/sig2)*(repmat(chi_nn,1,T).*(1-2*m).*X2)...
        +log(m./(1-m)) -(X.*(A'*(Ytilde/sig2)));
    m = m -eta0*dFdm;
    m = max(m,sqrt(eps));
    m = min(m,1-sqrt(eps));
    % Check for convergence
    Beta(k) = 1/sig2;
    if k>k_beta_conv 
        if abs(Beta(k)-Beta(k-5))<beta_tol && abs(Beta(k)-Beta(k-1))<beta_tol
            term = 1;
        end
    end
    Mits(k) = sum(sum(m>0.5));
    if k>k_m_conv&&abs(Mits(k)-Mits(k-1000))<m_tol*N*T;
        term = 1;
    end
end
M = m(:,1:end-1);X = X(:,1:end-1);
X2 = (X.*X);
V = X.*M;
F = calcFreeMarkov(A,Beta(k),Y(:,1:end-1),Ytilde(:,1:end-1),Q,M,X,X2,chi_nn);

if nargout>4
    T = size(M,2);
    Kv = size(opts.A_val,1);
    chi_nn =  1/Kv*sum(opts.A_val.^2)';
    Ytilde = zeros(size(opts.Y_val));
    for t = 1:T,
        AB = opts.A_val.*repmat(((M(:,t)./(1-M(:,t)))./chi_nn)',Kv,1); % del af C
        BB = eye(Kv)+opts.A_val*AB'/(Kv);
        Ytilde(:,t) = pinv(BB)*opts.Y_val(:,t);
    end
    Fval = calcFreeMarkov(opts.A_val,Beta(k),opts.Y_val,Ytilde,Q,M,X,X2,chi_nn);
end