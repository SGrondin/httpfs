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
            this.Client = new RestClient { BaseUrl = new Uri(config.ServerRootPath) };
        }

        #endregion

        #region Properties

        private RestClient Client { get; set; }

        #endregion

        #region Methods

        public async Task<ListDirectoryResult> ListDirectory(Url path)
        {
            var request = new RestRequest(path, Method.GET);

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
            var request = new RestRequest(path, Method.GET);

            var fileBytes = await this.Client.ExecuteGetTaskAsync(request);

            if (fileBytes.Headers.Any(h => h.Name == "is-directory"))
            {
                throw new Exception();
            }

            if (!Directory.Exists(to.GetDirectoryName()))
            {
                Directory.CreateDirectory(to.GetDirectoryName());
            }

            File.WriteAllText(to.GetFullPath(), fileBytes.Content);
        }

        #endregion
    }
}