<html>
<style>
        @import url(http://fonts.googleapis.com/css?family=Open+Sans);
</style>
<body>
<div align="center">
        <table order="0" cellspacing="0" cellpadding="0" style="width:640px;height:92px;background:#414042">
                <tr>
                        <td style="padding:20px 0px 19.15px 40px;width:91px;height:36px;background:#414042">
                                <a href="" target="_blank">
                                        <img src='${FileExchangeURL}/CompanyLogoForDarkBar.svg' width="91" height="36">
                                </a>
                        </td>
                        <td style="padding:20px 0px 19.15px 40px;width:91px;height:36px;background:#414042">
                                        <span style="font-size:20px;text-align:left; font-family:Open Sans,sans-serif;color:#FFFFFF; line-height:26px;font-weight:500;letter-spacing: -0.1px;">
                                                                File Exchange Access<br>

                                        </span>
                        </td>
                </tr>
        </table>
</div>

<div align="center">
        <table order="0" cellspacing="0" cellpadding="0"  width="640">
                <tr>
                        <td style="padding:36px 40px 16px 40px;">
                                <div style="line-height:26px">
                            <span style="font-size:16px; font-family:Open Sans;letter-spacing:0px;color:#2E2734; line-height:26px;font-weight:500;letter-spacing: -0.1px;">
                                Hello,<br>
                                                                You have been granted access to ${b2bCompanyName}’s File Transfer server.<br>
                                To access the server, use the following credentials.<br>
                            </span>
                                </div>
                        </td>
                </tr>
                <tr>
                        <td style="padding:0px 40px 20px 40px;">
                                <div style="line-height:26px">
                                <span style="font-size:16px; font-family:Open Sans;letter-spacing: 0px;color:#333333; line-height:26px;font-weight:600">
                                    User name:<br>
                                </span>
                                        <span style="font-size:16px; font-family:Open Sans;letter-spacing: 0px;color:#2E2734; line-height:26px;font-weight:400">
                                    ${userName}
                                </span>
                                </div>
                        </td>
                </tr>
                <tr>
                        <td style="padding:0px 40px 36px 40px;">
                                <div style="line-height:26px">
                                <span style="font-size:16px; font-family:Open Sans;letter-spacing: 0px;color:#333333; line-height:26px;font-weight:600">
                                    Password:<br>
                                </span>
                                        <span style="font-size:16px; font-family:Open Sans;letter-spacing: 0px;color:#2E2734; line-height:26px;font-weight:400">
                                    ${password}<br>(You will be asked to change it after you log in)
                                </span>
                                </div>
                        </td>
                </tr>
                <tr>
                        <td style="padding:0px 40px 16px 40px;">
                            <span style="font-size:16px; font-family:Open Sans;letter-spacing:0px;color:#2E2734; line-height:26px;font-weight:500;letter-spacing: -0.1px;">
                                You must activate your account within <${temporaryPasswordPeriod}> hours.<br>
                                To activate your user, log in to the <a href="${FileExchangeURL}" style="color: #00A79D">File Exchange website</a> and change your password.<br>
                                                                <br>
                                                                For any issues, contact <a href="mailto:${b2bCompanyMailAddress}" style="color: #00A79D">${b2bCompanyMailAddress}<a>.<br>
                                                                <br>
                                                                Thanks,<br>
                                                                The ${b2bCompanyName}
                            </span>
                        </td>
                </tr>

        </table>
</div>


</div>

</body>