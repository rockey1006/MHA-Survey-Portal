class EvidenceUploadsController < ApplicationController
  before_action :set_evidence_upload, only: %i[ show edit update destroy ]

  # GET /evidence_uploads or /evidence_uploads.json
  def index
    @evidence_uploads = EvidenceUpload.all
  end

  # GET /evidence_uploads/1 or /evidence_uploads/1.json
  def show
  end

  # GET /evidence_uploads/new
  def new
    @evidence_upload = EvidenceUpload.new
  end

  # GET /evidence_uploads/1/edit
  def edit
  end

  # POST /evidence_uploads or /evidence_uploads.json
  def create
    @evidence_upload = EvidenceUpload.new(evidence_upload_params)

    respond_to do |format|
      if @evidence_upload.save
        format.html { redirect_to @evidence_upload, notice: "Evidence upload was successfully created." }
        format.json { render :show, status: :created, location: @evidence_upload }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @evidence_upload.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /evidence_uploads/1 or /evidence_uploads/1.json
  def update
    respond_to do |format|
      if @evidence_upload.update(evidence_upload_params)
        format.html { redirect_to @evidence_upload, notice: "Evidence upload was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @evidence_upload }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @evidence_upload.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /evidence_uploads/1 or /evidence_uploads/1.json
  def destroy
    @evidence_upload.destroy!

    respond_to do |format|
      format.html { redirect_to evidence_uploads_path, notice: "Evidence upload was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_evidence_upload
      @evidence_upload = EvidenceUpload.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def evidence_upload_params
      params.require(:evidence_upload).permit(:evidenceupload_id, :questionresponse_id, :competencyresponse_id, :link)
    end
end
