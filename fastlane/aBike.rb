$:.unshift File.dirname("../.." + __FILE__)

require '../Various/version.rb'

module CPaBike

VERSION = getCurrentBuildVersion

RELEASE_NOTES = ({

	'en-US' => "Bug fixes",
	'fr-FR' => "Corrections de bugs",
	'en-GB' => "Bug fixes"

})

SUBMIT_FOR_REVIEW = true

AUTOMATIC_RELEASE = true

SUBMISSION_INFORMATION = ({
	add_id_info_uses_idfa: false
})

end
