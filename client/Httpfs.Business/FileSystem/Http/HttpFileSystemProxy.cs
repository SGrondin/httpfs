using System;
using System.IO;
using System.Threading.Tasks;

using Flurl;
using Flurl.Http;

using Httpfs.Client.Business.FileSystem.Results.List;

using httpfsc.Business.FileSystem.Http;

namespace Httpfs.Client.Business.FileSystem.Http
{
    public class HttpFileSystemProxy
    {
        private IHttpFileSystemProxyConfig Config { get; set; }

        #region Constructors

        public HttpFileSystemProxy(IHttpFileSystemProxyConfig config)
        {
            this.Config = config;
        }

        #endregion

        #region Methods

        public async Task<ListDirectoryResult> ListDirectory(Url path)
        {
            var files = await this.Config.ServerRootPath
                .AppendPathSegment(path)
                .GetAsync();

            if (!files.Headers.Contains("IS-DIRECTORY"))
            {
                throw new Exception();
            }

            var list = await files.Content.ReadAsStringAsync();

            return list != null
                ? ListDirectoryResult.FromResponse(list)
                : ListDirectoryResult.FromEmptyResponse();
        }

        public async void DownloadFile(Url path, Url to)
        {
            var fileBytes = await this.Config.ServerRootPath
                .AppendPathSegment(path)
                .GetAsync();

            if (fileBytes.Headers.Contains("IS-DIRECTORY"))
            {
                throw new Exception();
            }

            File.WriteAllBytes(to, await fileBytes.Content.ReadAsByteArrayAsync());
        }

        #endregion
    }
}