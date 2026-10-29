require 'json'
require 'digest'
require 'time'

platform :ios do
  lane :publish_candidate do
    UI.user_error!('Owner-authorized normal-identity upload required') unless
      ENV['GITHUB_ACTIONS'] == 'true' && ENV['GITHUB_REF'] == 'refs/heads/migration/loop4-ai-photo' &&
      ENV['OWNER_AUTHORIZED_UPDATE'] == 'PUBLISH_LOOP_28_AND_TEXT_INPUT' && ENV['BACKEND_RELEASE_RESULT'] == 'success'
    directory = File.join(ENV.fetch('RUNNER_TEMP'), 'NextReleaseCandidate')
    ipa = ENV.fetch('LOOP_VERIFIED_RELEASE_IPA')
    candidate = JSON.parse(File.read(File.join(directory, 'VerifiedNextRelease.json')))
    identity = 'com.279LYMG57A.loopkit.Loop'
    UI.user_error!('Wrong or unverified signed candidate') unless
      candidate.fetch('source') == '562919d74ff3b2ab1222e8c8ebc9e61c720ff01a' &&
      candidate.fetch('ipa_sha256') == '43465f88c4758bc36fc37982fa5ed79520ccb9071fd71fae98d24a3f19009986' &&
      Digest::SHA256.file(ipa).hexdigest == candidate.fetch('ipa_sha256') &&
      candidate.fetch('bundle') == identity && candidate.fetch('app_group') == 'group.' + identity + 'Group' &&
      candidate.fetch('version') == '3.15.2' && candidate.fetch('build') == '28' &&
      candidate.fetch('signature_verified') == true
    api_key = app_store_connect_api_key(key_id: ENV.fetch('FASTLANE_KEY_ID'),
                                      issuer_id: ENV.fetch('FASTLANE_ISSUER_ID'),
                                      key_content: ENV.fetch('FASTLANE_KEY'))
    app = Spaceship::ConnectAPI::App.find(identity)
    UI.user_error!('Existing production app record missing') unless app && app.bundle_id == identity && app.id == '6737123014'
    find_build = lambda do
      Spaceship::ConnectAPI::Build.all(app_id: app.id, version: '3.15.2', build_number: '28', platform: 'IOS').first
    end
    UI.user_error!('Build 28 already exists; inspect its retained upload evidence before retrying') if find_build.call ||
      Spaceship::ConnectAPI::BuildUpload.all(app_id: app.id, version: '3.15.2', build_number: '28').first
    latest = latest_testflight_build_number(api_key: api_key, app_identifier: identity)
    UI.user_error!('Production build history changed; inspect it before publishing') unless latest.to_i == 27
    status = candidate.slice('source', 'bundle', 'version', 'build', 'ipa_sha256')
    status.merge!('app_id' => app.id, 'upload_accepted' => false, 'processing_state' => 'NOT_UPLOADED',
                  'external_distribution' => false, 'device_installed' => false,
                  'independently_validated_for_therapy' => false)
    save = lambda do
      status['checked_at'] = Time.now.utc.iso8601
      File.write(File.join(directory, 'NextUploadStatus.json'), JSON.pretty_generate(status) + "\n")
      UI.message('NEXT_LOOP_UPLOAD: ' + JSON.generate(status))
    end
    begin
      save.call
      upload_to_testflight(api_key: api_key, app_identifier: identity, apple_id: app.id, ipa: ipa,
                           skip_waiting_for_build_processing: true, skip_submission: true,
                           distribute_external: false, notify_external_testers: false,
                           changelog: 'Experimental Loop next-dev (3.15.2), with camera, gallery and written meal analysis. Editable carbs, absorption time, notes, comment refinement and explicit reviewed handoff are preserved. Automated checks and photo testing do not independently validate therapy or device behavior. This update migrates the existing app database; a data-compatible downgrade is not guaranteed.')
      status['upload_accepted'] = true
      status['processing_state'] = 'AWAITING_APPLE_RECORD'
      save.call
      deadline = Time.now + 20 * 60
      loop do
        build = find_build.call
        ingestion = Spaceship::ConnectAPI::BuildUpload.all(app_id: app.id, version: '3.15.2', build_number: '28').first
        if ingestion
          details = ingestion.state
          state = details.is_a?(Hash) ? details['state'] : details
          status['upload_processing_state'] = state
          UI.user_error!('Apple rejected ingestion; inspect NextUploadStatus.json') if state == 'FAILED'
        end
        if build
          status['build_id'] = build.id
          status['processing_state'] = build.processing_state
          status['internal_build_state'] = build.build_beta_detail&.internal_build_state
          status['missing_export_compliance'] = build.missing_export_compliance? if build.build_beta_detail
          break if ['FAILED', 'INVALID'].include?(build.processing_state) ||
            (build.processing_state == 'VALID' &&
             ['READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].include?(status['internal_build_state']) &&
             status['missing_export_compliance'] == false)
        end
        break if Time.now >= deadline
        sleep(30)
      end
      UI.user_error!('Apple rejected the candidate; inspect NextUploadStatus.json') if ['FAILED', 'INVALID'].include?(status['processing_state'])
      UI.user_error!('Upload retained but Apple has not confirmed internal testing readiness; inspect status before retrying') unless
        status['processing_state'] == 'VALID' &&
        ['READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].include?(status['internal_build_state']) &&
        status['missing_export_compliance'] == false
    ensure
      save.call
    end
  end
end
