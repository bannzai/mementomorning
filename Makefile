XCODEPROJ := MementoMorning.xcodeproj
SCHEME := MementoMorning
CONFIGURATION := Debug
DERIVED_DATA := tmp/DerivedData
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphonesimulator/MementoMorning.app
IOS_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphoneos/MementoMorning.app
BUNDLE_ID := com.bannzai.MementoMorning

.PHONY: build device install-device run test clean

# Simulator 向けビルド。generic destination なら simulator の起動なしでビルドできる
build:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# 実機向けビルド。code signing が必要なため、provisioning profile の自動生成とこの Mac へのデバイス登録を CLI から行えるようにする
device:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build

# 実機ビルドを実機にインストールする。インストール先の解決順: DEVICE 変数 (名前 / UDID) > 環境変数 IOS_DEVICE_UDID > devicectl の JSON から接続中デバイスを自動解決
install-device: device
	@mkdir -p tmp; \
	device="$(DEVICE)"; \
	[ -n "$$device" ] || device="$(IOS_DEVICE_UDID)"; \
	if [ -z "$$device" ]; then \
		xcrun devicectl list devices --json-output tmp/devices.json > /dev/null; \
		device=$$(jq -r '[.result.devices[] | select(.connectionProperties.tunnelState == "connected")][0].identifier // empty' tmp/devices.json); \
	fi; \
	[ -n "$$device" ] || { echo "Error: 実機が見つかりません (IOS_DEVICE_UDID を export するか DEVICE=<名前|UDID> で指定してください)" >&2; exit 1; }; \
	xcrun devicectl device install app --device "$$device" "$(IOS_APP)"; \
	xcrun devicectl device process launch --device "$$device" $(BUNDLE_ID)

# Simulator 向けビルドを起動中の simulator にインストールして起動する (simulator は sim-boot で用意する)
run: build
	xcrun simctl install booted $(APP)
	xcrun simctl launch booted $(BUNDLE_ID)

test:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf $(DERIVED_DATA)
