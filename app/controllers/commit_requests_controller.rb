class CommitRequestsController < ApplicationController
  # GET /commit_requests
  # GET /commit_requests.xml
  def index
    @commit_requests = CommitRequest.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @commit_requests }
    end
  end

  # GET /commit_requests/1
  # GET /commit_requests/1.xml
  def show
    @commit_request = CommitRequest.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @commit_request }
    end
  end

  # GET /commit_requests/new
  # GET /commit_requests/new.xml
  def new
    @commit_request = CommitRequest.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @commit_request }
    end
  end

  # GET /commit_requests/1/edit
  def edit
    @commit_request = CommitRequest.find(params[:id])
  end

  # POST /commit_requests
  # POST /commit_requests.xml
  def create
    @commit_request = CommitRequest.new(params[:commit_request])
    @commit_request.user_id = params[:user_id] unless params[:user_id].blank?
    @commit_request.issue_id = params[:issue_id] unless params[:issue_id].blank?
    @commit_request.response = params[:response] unless params[:response].blank?
    @commit_request.days = params[:days] unless params[:days].blank?
    @lock_version = ''

    if @commit_request.response == 2 #somebody is taking this issue
      #we set the responder id equal to the author id
      @commit_request.responder_id = @commit_request.user_id
      #Updating issue status to committed if user_id is current user_id (and change response type to 1 for accepted)
      @user = User.find(@commit_request.user_id)
      @issue = Issue.find(@commit_request.issue_id)
      @issue.assigned_to = @user
      @issue.expected_date = Time.new() + 3600*24*@commit_request.days unless @commit_request.days < 0
      @issue.status = IssueStatus.assigned
      @issue.save      
      @lock_version = @issue.lock_version
      CommitRequest.update_notifications_and_commit_requests(User.current,@issue,true,false)
    else
      @commit_request.responder_id = params[:responder_id]      
    end
        

    respond_to do |format|
      if @commit_request.save
        
        #We successfully added the request, let's notify whoever needs the notification if this was an offer
        if @commit_request.response == 4 #offering this issue to someone
          @issue = Issue.find(@commit_request.issue_id)
          Notification.create params[:responder_id],
                              'commit_request_offer',
                              ":issue_subject => '#{@issue.subject}', :sender_id => #{@commit_request.user_id}, :issue_id => #{@issue.id}, :cr_id => #{@commit_request.id}, :cr_days => #{@commit_request.days}",
                              @commit_request.issue_id
        elsif @commit_request.response == 0 #someone is requesting this issue
          logger.info("response is 0, we're creating a notification")
          @issue = Issue.find(@commit_request.issue_id)
          @recipient = @issue.assigned_to.nil? ? @issue.author : @issue.assigned_to #send notification to owner, if no owner then send to author
          logger.info("Recipient #{@recipient}:  is owner: #{@issue.assigned_to.nil?.to_s}")
          if @issue.push_allowed?(@recipient)
            logger.info("#{@recipient} is allowed, we're creating notification")
            Notification.create @recipient.id,
                                'commit_request',
                                ":issue_subject => '#{@issue.subject}', :sender_id => #{@commit_request.user_id}, :issue_id => #{@issue.id}, :cr_id => #{@commit_request.id}, :cr_days => #{@commit_request.days}, :is_recipient_owner => #{(!@issue.assigned_to.nil?).to_s}",
                                @commit_request.issue_id
          end
        end
        
        # flash[:notice] = 'Request for commitment was successfully sent.'
        # format.js  { render :action => "create", :commit_request => @commit_request, :user => @commit_request.user_id, :issue => @commit_request.issue_id}        
        format.js  { render :action => "create", :commit_request => @commit_request, :lock_version => @lock_version}        
        format.html { redirect_to(@commit_request) }
        format.xml  { render :xml => @commit_request, :status => :created, :location => @commit_request }
      else
        format.js  { render :action => "error"}        
        format.html { render :action => "new" }
        format.xml  { render :xml => @commit_request.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def create_dialogue
  end

  def select_user_dialogue(options ={})
    logger.info("Options #{params.inspect}")
    @issue = Issue.find(params['issue_id'])
  end


  # PUT /commit_requests/1
  # PUT /commit_requests/1.xml
  def update
    ##BUGBUG Should we be checking permissions AGAIN here? Just in case someone is hacking the url to gain access to tasks?
    @commit_request = CommitRequest.find(params[:id])
    @commit_request.response = params[:response]
    @commit_request.responder_id = params[:responder_id]
    @commit_request.days = params[:days] unless params[:days].nil?
    @commit_request.save

    @issue = Issue.find(@commit_request.issue)    
    
    # 0- Request No response 1-Request recinded 2-Request Accepted 3-Request Declined 4-Offer no response 5-Offer recinded 6-Offer accepted 7-Offer Declined 8-Ownership Released
    case @commit_request.response
    when 2 #somebody is accepting someone else's request for this issue
      #Notify requester that his notification has been accepted
      Notification.create @commit_request.user_id,
                          'message',
                          ":subject => '#{l(:text_ownership_request_accepted)}', :message => '#{l(:text_you_are_the_new_owner_of)} #{@template.link_to_issue(@issue, {:include_subject => :true})}', :sender_id => #{User.current.id}",
                          @commit_request.issue_id
    when 3 #somebody is declining someone else's request for this issue      
      #Notify requester that their notification has been declined
      Notification.create @commit_request.user_id,
                          'message',
                          ":subject => '#{l(:text_ownership_request_declined)}', :message => '#{l(:text_your_ownsership_request_declined_for)} #{@template.link_to_issue(@issue, {:include_subject => :true})}', :sender_id => #{User.current.id}",
                          @commit_request.issue_id            
    when 6 #somebody is accepting an offer for this issue
      #Notify offerer that their offer has been accepted
      Notification.create @commit_request.user_id,
                          'message',
                          ":subject => '#{l(:text_ownership_offer_accepted)}', :message => '#{l(:text_your_offer_was_accepted_for)} #{@template.link_to_issue(@issue, {:include_subject => :true})}', :sender_id => #{User.current.id}",
                          @commit_request.issue_id      
      
    when 7 #declining an offer
      #Notify offerer that their offer has been declined
      Notification.create @commit_request.user_id,
                          'message',
                          ":subject => '#{l(:text_ownership_offer_declined)}', :message => '#{l(:text_your_offer_was_declined_for)} #{@template.link_to_issue(@issue, {:include_subject => :true})}', :sender_id => #{User.current.id}",
                          @commit_request.issue_id      
    end 

    respond_to do |format|
      logger.info("Entering response in commit request controller formate #{format.to_s}")
      if (!params[:notification_id].nil?)
        logger.info("This request came from a notification")
        render :template => "notifications/hide", :layout => false
        return
      else      
        format.js  { render :action => "update", :commit_request => @commit_request, :created_on => @commit_request.created_on, :updated_on => @commit_request.updated_on, :lock_version => @issue.lock_version}        
        format.html { redirect_to(commit_requests_url) }
        format.xml  { head :ok }
      end
    end
  end

  # DELETE /commit_requests/1
  # DELETE /commit_requests/1.xml
  def destroy
    @commit_request = CommitRequest.find(params[:id])
    @commit_request.destroy

    respond_to do |format|
      format.js  { render :action => "destroy", :commit_request => @commit_request}        
      # format.html { redirect_to(commit_requests_url) }
      # format.xml  { head :ok }
    end
  end
  
end