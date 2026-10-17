require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  let(:signup_params) do
    { name: 'New User', email: 'New@Example.com', password: 'supersecret', password_confirmation: 'supersecret',
      form_token: form_token(started: 1.minute.ago) }
  end

  def form_token(started:) = Rails.application.message_verifier(:signup_form).generate(started.to_i, expires_in: 1.day)

  after do
    doc = begin
      CouchDB.auth_db.get('email__new@example.com')
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  describe 'GET new' do
    render_views

    it 'renders the form with the honeypot and a form token' do
      get :new, params: { email: 'invitee@example.com' }

      expect(response.body).to include('name="website"', 'name="form_token"', 'value="invitee@example.com"')
    end
  end

  describe 'POST create' do
    context 'with views' do
      render_views

      it 'tells the person to check their email' do
        post :create, params: signup_params

        expect(response.body).to include('Check your email', 'new@example.com')
      end
    end

    it 'creates an unconfirmed account, emails a confirmation link, and does not sign in' do
      expect { post :create, params: signup_params }
        .to change { User.find_all.size }.by(1)
        .and have_enqueued_mail(UserMailer, :email_verification).with('email__new@example.com')

      expect(session[:user_id]).to be_nil
      expect(response).to render_template(:check_email)
      expect(User.for_email('new@example.com')).to be_pending_verification
    end

    it 'rejects a too-short password and does not sign in' do
      post :create, params: signup_params.merge(password: 'short', password_confirmation: 'short')

      expect(session[:user_id]).to be_nil
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'quietly drops a submission that filled in the honeypot' do
      expect do
        post :create, params: signup_params.merge(website: 'http://spam.example')
      end.not_to(change { User.find_all.size })

      expect(response).to render_template(:check_email)
      expect { post :create, params: signup_params.merge(website: 'x') }.not_to have_enqueued_mail
    end

    it 'quietly drops a submission made faster than a person could type' do
      expect do
        post :create, params: signup_params.merge(form_token: form_token(started: Time.current))
      end.not_to(change { User.find_all.size })

      expect(response).to render_template(:check_email)
    end

    it 'rejects a submission without a valid form token' do
      expect do
        post :create, params: signup_params.merge(form_token: 'forged')
      end.not_to(change { User.find_all.size })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 're-sends the confirmation link when an unconfirmed account signs up again' do
      post :create, params: signup_params

      expect do
        post :create, params: signup_params
      end.to have_enqueued_mail(UserMailer, :email_verification)
      expect(response).to render_template(:check_email)
    end

    it "doesn't reveal or email anything when a confirmed account already exists" do
      post :create, params: signup_params
      User.for_email('new@example.com').verify_email!

      expect do
        post :create, params: signup_params
      end.not_to have_enqueued_mail
      expect(response).to render_template(:check_email)
    end
  end

  context 'when mail is not configured' do
    include_context 'without mail'

    it 'creates a confirmed account and signs straight in' do
      expect { post :create, params: signup_params }.not_to have_enqueued_mail

      expect(session[:user_id]).to be_present
      expect(response).to redirect_to(controller.root_path)
      expect(User.for_email('new@example.com')).not_to be_pending_verification
    end

    it 'says so when the address already has an account' do
      post :create, params: signup_params
      session.delete(:user_id)

      post :create, params: signup_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:error]).to match(/already exists/)
    end

    it 'still drops honeypot submissions' do
      expect do
        post :create, params: signup_params.merge(website: 'http://spam.example')
      end.not_to(change { User.find_all.size })
    end
  end
end
