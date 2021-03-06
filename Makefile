LAYER_NAME ?= headless-chromium-layer
LAYER_DESC ?=headless-chromium-layer
S3BUCKET ?= pahud-me-tmp-nrt
LAMBDA_REGION ?= ap-northeast-1
LAMBDA_FUNC_NAME ?= headless-chromium-layer-test-func
LAMBDA_FUNC_DESC ?= headless-chromium-layer-test-func
LAMBDA_ROLE_ARN ?= arn:aws:iam::643758503024:role/LambdaRoleWithS3Upload

build:
	@bash build.sh
	
layer-zip:
	( rm -f layer.zip; cd layer; zip -r ../layer.zip * )
	
layer-upload:
	@aws s3 cp layer.zip s3://$(S3BUCKET)/$(LAYER_NAME).zip
	
layer-publish:
	@aws --region $(LAMBDA_REGION) lambda publish-layer-version \
	--layer-name $(LAYER_NAME) \
	--description $(LAYER_DESC) \
	--license-info "MIT" \
	--content S3Bucket=$(S3BUCKET),S3Key=$(LAYER_NAME).zip \
	--compatible-runtimes provided
	
func-zip:
	chmod +x main.sh
	rm -f func-bundle.zip
	zip -r func-bundle.zip bootstrap main.sh; ls -alh func-bundle.zip
	# zip -r func-bundle.zip bootstrap main.sh .fonts .fontconfig; ls -alh func-bundle.zip
	
create-func: func-zip
	@aws --region $(LAMBDA_REGION) lambda create-function \
	--function-name $(LAMBDA_FUNC_NAME) \
	--description $(LAMBDA_FUNC_DESC) \
	--runtime provided \
	--role  $(LAMBDA_ROLE_ARN) \
	--timeout 30 \
	--memory-size 1536 \
	--layers $(LAMBDA_LAYERS) \
	--handler main \
	--zip-file fileb://func-bundle.zip 

update-func: func-zip
	@aws --region $(LAMBDA_REGION) lambda update-function-code \
	--function-name $(LAMBDA_FUNC_NAME) \
	--zip-file fileb://func-bundle.zip
	
func-all: func-zip update-func
layer-all: build layer-upload layer-publish


invoke:
	@aws --region $(LAMBDA_REGION) lambda invoke --function-name $(LAMBDA_FUNC_NAME)  \
	--payload "" lambda.output --log-type Tail | jq -r .LogResult | base64 -d
	
add-layer-version-permission:
	@aws --region $(LAMBDA_REGION) lambda add-layer-version-permission \
	--layer-name $(LAYER_NAME) \
	--version-number $(LAYER_VER) \
	--statement-id public-all \
	--action lambda:GetLayerVersion \
	--principal '*'
	

all: build layer-upload layer-publish
	
clean:
	rm -rf awscli-bundle* layer layer.zip func-bundle.zip lambda.output
	
delete-func:
	@aws --region $(LAMBDA_REGION) lambda delete-function --function-name $(LAMBDA_FUNC_NAME)
	
clean-all: clean delete-func

	
