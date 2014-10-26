<!DOCTYPE html>
<html lang="en">
   <head profile="http://www.w3.org/2005/10/profile">
      <link rel="icon" type="image/ico" href="/static/images/favicon.v3.ico" />

      <apply template="headers/aui" />
      <apply template="headers/aui-experimental" />
      <script type="text/javascript" src="//cdnjs.cloudflare.com/ajax/libs/marked/0.3.2/marked.min.js"></script>

      <script type="text/javascript" src="/static/js/doc-page-loaded.js"></script>
   </head>
   <body>
      <header id="header" role="banner">
      <!-- App Header goes inside #header -->

        <nav class="aui-header aui-dropdown2-trigger-group" role="navigation">
            <div class="aui-header-primary">
                <h1 id="logo" class="aui-header-logo aui-header-logo-custom"><a href="/"><span class="aui-header-logo-text">Remind Me</span></a></h1>
                <ul class="aui-nav">
                    <!-- You can also use a split button in this location, if more than one primary action is required. -->
                    <li><a class="aui-button aui-button-primary" href="https://marketplace.atlassian.com/plugins/com.atlassian.ondemand.remindme">Install plugin</a></li>
                </ul>
            </div>
            <div class="aui-header-secondary">
                <ul class="aui-nav">
                    <li><a href="#dropdown2-header7" aria-owns="dropdown2-header7" aria-haspopup="true" class="aui-dropdown2-trigger-arrowless aui-dropdown2-trigger" aria-controls="dropdown2-header7"><span class="aui-icon aui-icon-small aui-iconfont-help">Help</span></a>
                      <div class="aui-dropdown2 aui-style-default aui-dropdown2-in-header" id="dropdown2-header7" style="display: none; top: 40px; min-width: 160px; left: 1213px; " aria-hidden="true">
                          <div class="aui-dropdown2-section">
                              <ul>
                                  <li><a href="http://example.com/">Report a bug</a></li>
                                  <li><a href="http://example.com/">About</a></li>
                              </ul>
                          </div>
                      </div>
                    </li>
                </ul>
            </div>
        </nav>

      <!-- App Header goes inside #header -->
      </header>

      <div class="aui-page-panel-nav">
<!-- Vertical Nav is usually placed inside .aui-page-panel-nav. Refer to content layout documentation for details. -->

    <nav class="aui-navgroup aui-navgroup-vertical">
        <div class="aui-navgroup-inner">
            <ul class="aui-nav">
                <li class="aui-nav-selected"><a href="/">Welcome</a></li>
            </ul>
            <div class="aui-nav-heading"><strong>More</strong></div>
            <ul class="aui-nav">
                <li><a href="http://example.com/">About</a></li>
                <li><a href="http://example.com/">Frequently asked questions</a></li>
                <li><a href="http://example.com/">Report a bug</a></li>
            </ul>
        </div>
    </nav>

   <!-- Vertical Nav is usually placed inside aui-page-panel-nav -->
   </div>

   <div class="hidden" id="page-markdown-content"><apply-content /></div>
   <section id="page-html-content" class="aui-page-panel-content">
       <p>Loading page content...</p>
   </section>
   </body>
</html>
