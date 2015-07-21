using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

using httpfsc.Business.Http.FileSystem.Results.List;

using RestSharp;

namespace httpfsc.Business.Http
{
    public class HttpFileSystemProxy
    {
        #region Constructors

        public HttpFileSystemProxy(IHttpFileSystemProxyConfig config)
        {
            this.Config = config;

            this.Client = new RestClient { BaseUrl = new Uri(config.ServerRootPath) };
        }

        #endregion

        #region Properties

        private IHttpFileSystemProxyConfig Config { get; set; }
        private RestClient Client { get; set; }

        #endregion

        #region Methods

        public async Task<ListDirectoryResult> ListDirectory(Url path)
        {
            var requestPath = this.Config.ServerRootPath.Combine(path);
            var request = new RestRequest(requestPath, Method.GET);

            var files = await this.Client.ExecuteGetTaskAsync(request);

            if (files.Headers.All(h => h.Name != "is-directory"))
            {
                throw new Exception();
            }

            var list = files.Content;

            return list != null
                ? ListDirectoryResult.FromResponse(list)
                : ListDirectoryResult.FromEmptyResponse();
        }

        public async void DownloadFile(Url path, Url to)
        {
            var requestPath = this.Config.ServerRootPath.Combine(path);
            var request = new RestRequest(requestPath, Method.GET);

            var fileBytes = await this.Client.ExecuteGetTaskAsync(request);

            if (fileBytes.Headers.Contains(new Parameter { Name = "IS-DIRECTORY" }))
            {
                throw new Exception();
            }

            File.WriteAllText(to, fileBytes.Content);
        }

        #endregion
    }
}